#!/usr/bin/env bash
set -Eeuo pipefail

kvm_network_precheck() {
  assert_scope KVM
  command -v ip >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v python3 >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/virtualization/systemd/ubuntu-desktops-custom-kvm-guard.service" ]] || return "$EXIT_PRECHECK_FAILED"

  python3 - "${KVM_NETWORK_CIDR:-192.168.50.0/24}" <<'PY' || return "$EXIT_MANUAL_ACTION_REQUIRED"
import ipaddress
import subprocess
import sys
kvm = ipaddress.ip_network(sys.argv[1], strict=False)
out = subprocess.run(['ip', '-4', 'route', 'show', 'scope', 'link'], text=True, capture_output=True, check=True).stdout
for line in out.splitlines():
    first = line.split()[0] if line.split() else ''
    if '/' not in first:
        continue
    network = ipaddress.ip_network(first, strict=False)
    if network == kvm:
        continue
    if kvm.overlaps(network):
        print(f'KVM subnet overlap detected with {network}', file=sys.stderr)
        raise SystemExit(10)
PY
}

kvm_network_plan() {
  cat <<'EOF'
KVM CUSTOM NAT APPLY PLAN:
- install nftables dependency without replacing/flushing the HOST firewall
- install a project-owned nftables guard helper and systemd service
- the guard dynamically discovers directly-connected HOST IPv4 networks and blocks VM<->those networks only
- the project owns only table inet ubuntu_desktops_custom_kvm; rollback deletes only that table
- activate the isolation guard before starting devops-nat (fail-closed order)
- define devops-nat only when absent; refuse to overwrite a conflicting existing network
- libvirt XML enforces DNS forwarders 9.9.9.9 and 1.1.1.1
- start/autostart devops-nat only after the guard is active
- HOST<->VM and VM<->VM remain allowed; VM->Internet remains NATed by libvirt
- all mutations are executed only through run_mutating
EOF
}

kvm_network_apply() {
  local uri="${LIBVIRT_URI:-qemu:///system}"
  local network="${KVM_NETWORK_NAME:-devops-nat}"
  local xml="$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
  local helper_src="$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  local helper_dst='/usr/local/libexec/ubuntu-desktops-custom/kvm-network-guard'
  local unit_src="$REPO_ROOT/virtualization/systemd/ubuntu-desktops-custom-kvm-guard.service"
  local unit_dst='/etc/systemd/system/ubuntu-desktops-custom-kvm-guard.service'

  run_mutating KVM sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install nftables python3 iproute2 || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -d -m 0755 /usr/local/libexec/ubuntu-desktops-custom || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -m 0755 "$helper_src" "$helper_dst" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo install -m 0644 "$unit_src" "$unit_dst" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo systemctl daemon-reload || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo systemctl enable --now ubuntu-desktops-custom-kvm-guard.service || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    run_mutating KVM sudo virsh --connect "$uri" net-define "$xml" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "$uri" net-start "$network" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "$uri" net-autostart "$network" || return "$EXIT_APPLY_FAILED"
    return 0
  fi

  if sudo virsh --connect "$uri" net-info "$network" >/dev/null 2>&1; then
    local current
    current="$(sudo virsh --connect "$uri" net-dumpxml "$network")" || return "$EXIT_APPLY_FAILED"
    grep -Fq "<bridge name='${KVM_BRIDGE_NAME:-virbr50}'" <<< "$current" || return "$EXIT_MANUAL_ACTION_REQUIRED"
    grep -Fq "address='${KVM_GATEWAY:-192.168.50.254}'" <<< "$current" || return "$EXIT_MANUAL_ACTION_REQUIRED"
  else
    run_mutating KVM sudo virsh --connect "$uri" net-define "$xml" || return "$EXIT_APPLY_FAILED"
  fi

  if [[ "$(sudo virsh --connect "$uri" net-info "$network" | awk -F: '/Active/{gsub(/^[ \t]+/,"",$2); print $2}')" != yes ]]; then
    run_mutating KVM sudo virsh --connect "$uri" net-start "$network" || return "$EXIT_APPLY_FAILED"
  fi
  run_mutating KVM sudo virsh --connect "$uri" net-autostart "$network" || return "$EXIT_APPLY_FAILED"
}

kvm_network_postcheck() {
  [[ "${KVM_FAIL_CLOSED:-true}" == true ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "${KVM_NETWORK_CIDR:-}" == '192.168.50.0/24' ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "${KVM_DNS_ENFORCEMENT:-}" == 'libvirt-dns-forwarders' ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "${KVM_FIREWALL_ENFORCEMENT:-}" == 'project-nftables-guard' ]] || return "$EXIT_POSTCHECK_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: custom NAT runtime postcheck deferred'
    return 0
  fi

  sudo systemctl is-active --quiet ubuntu-desktops-custom-kvm-guard.service || return "$EXIT_POSTCHECK_FAILED"
  sudo nft list table inet "${KVM_NFT_TABLE:-ubuntu_desktops_custom_kvm}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "${KVM_NETWORK_NAME:-devops-nat}" | grep -Eq '^Active:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dumpxml "${KVM_NETWORK_NAME:-devops-nat}" | grep -Fq "<forwarder addr='9.9.9.9'" || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dumpxml "${KVM_NETWORK_NAME:-devops-nat}" | grep -Fq "<forwarder addr='1.1.1.1'" || return "$EXIT_POSTCHECK_FAILED"
}
