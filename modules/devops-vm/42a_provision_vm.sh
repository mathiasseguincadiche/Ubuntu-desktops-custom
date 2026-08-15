#!/usr/bin/env bash
set -Eeuo pipefail

vm_provision_paths() {
  local name="${VM_DEVOPS_NAME:-ubuntu-devops}"
  printf '%s|%s|%s\n' \
    "${KVM_POOL_PATH:-/data/libvirt/images}/base/${VM_DEVOPS_IMAGE:-ubuntu-26.04-server-cloudimg-amd64.img}" \
    "${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2" \
    "${KVM_POOL_PATH:-/data/libvirt/images}/seeds/${name}-seed.img"
}

vm_provision_identity() {
  local file="${STATE_ROOT:?}/${VM_DEVOPS_NAME:-ubuntu-devops}-vm-identity.env"
  [[ -s "$file" ]] || return "$EXIT_PRECHECK_FAILED"
  local mac ip
  mac="$(awk -F= '$1=="VM_DEVOPS_RESOLVED_MAC"{print $2}' "$file")"
  ip="$(awk -F= '$1=="VM_DEVOPS_RESOLVED_IP"{print $2}' "$file")"
  [[ -n "$mac" && -n "$ip" ]] || return "$EXIT_PRECHECK_FAILED"
  printf '%s|%s\n' "$mac" "$ip"
}

vm_provision_precheck() {
  assert_scope VM_DEVOPS
  command -v virsh >/dev/null 2>&1 || [[ "${DRY_RUN:-true}" == true ]] || return "$EXIT_PRECHECK_FAILED"
  command -v qemu-img >/dev/null 2>&1 || [[ "${DRY_RUN:-true}" == true ]] || return "$EXIT_PRECHECK_FAILED"
  command -v virt-install >/dev/null 2>&1 || [[ "${DRY_RUN:-true}" == true ]] || return "$EXIT_PRECHECK_FAILED"
  vm_provision_identity >/dev/null
}

vm_provision_plan() {
  cat <<'EOF'
UBUNTU-DEVOPS PROVISION PLAN:
- create an independent qcow2 working disk from the verified Ubuntu 26.04 cloud image
- resize working disk to 200 GiB
- add deterministic MAC/IP reservation to devops-nat before first boot
- create VM with 8 vCPU, 16 GiB RAM, virtio disk/network and UEFI firmware
- attach the NoCloud seed and boot via virt-install --import
- no VM autostart by default
- never expose a physical bridge or inbound port forward
- every mutation is executed only through run_mutating
EOF
}

vm_provision_apply() {
  local packed base disk seed identity mac ip
  local name="${VM_DEVOPS_NAME:-ubuntu-devops}"
  local network="${VM_DEVOPS_NETWORK:-devops-nat}"
  local uri="${LIBVIRT_URI:-qemu:///system}"
  packed="$(vm_provision_paths)"
  IFS='|' read -r base disk seed <<< "$packed"
  identity="$(vm_provision_identity)"
  mac="${identity%%|*}"
  ip="${identity##*|}"

  if ! is_true "${DRY_RUN:-true}"; then
    [[ -s "$base" && -s "$seed" ]] || return "$EXIT_APPLY_FAILED"
    if sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1; then
      log_info VM_DEVOPS "VM $name already defined; provisioning is idempotently skipped"
      return 0
    fi
    [[ ! -e "$disk" ]] || {
      log_error VM_DEVOPS "disk exists but VM is undefined: $disk"
      return "$EXIT_MANUAL_ACTION_REQUIRED"
    }
  fi

  run_mutating VM_DEVOPS sudo cp --reflink=auto --sparse=always "$base" "$disk" || return "$EXIT_APPLY_FAILED"
  run_mutating VM_DEVOPS sudo qemu-img resize "$disk" "${VM_DEVOPS_DISK_GB:-200}G" || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    run_mutating VM_DEVOPS sudo virsh --connect "$uri" net-update "$network" add ip-dhcp-host \
      "<host mac='$mac' name='$name' ip='$ip'/>" --live --config || return "$EXIT_APPLY_FAILED"
  else
    local xml
    xml="$(sudo virsh --connect "$uri" net-dumpxml "$network")" || return "$EXIT_APPLY_FAILED"
    if ! grep -Fiq "mac='$mac'" <<< "$xml"; then
      run_mutating VM_DEVOPS sudo virsh --connect "$uri" net-update "$network" add ip-dhcp-host \
        "<host mac='$mac' name='$name' ip='$ip'/>" --live --config || return "$EXIT_APPLY_FAILED"
    fi
  fi

  run_mutating VM_DEVOPS sudo virt-install \
    --connect "$uri" \
    --name "$name" \
    --memory "${VM_DEVOPS_RAM_MB:-16384}" \
    --vcpus "${VM_DEVOPS_VCPU:-8}" \
    --cpu host-passthrough \
    --import \
    --boot uefi \
    --disk "path=$disk,format=qcow2,bus=virtio,cache=none,discard=unmap" \
    --disk "path=$seed,device=cdrom" \
    --network "network=$network,model=virtio,mac=$mac" \
    --osinfo detect=on,require=off \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole || return "$EXIT_APPLY_FAILED"
}

vm_provision_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info VM_DEVOPS 'dry-run: VM provisioning postcheck deferred'
    return 0
  fi
  local name="${VM_DEVOPS_NAME:-ubuntu-devops}"
  local uri="${LIBVIRT_URI:-qemu:///system}"
  sudo virsh --connect "$uri" dominfo "$name" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "$uri" domiflist "$name" | grep -Fq "${VM_DEVOPS_NETWORK:-devops-nat}" || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "$uri" domblklist "$name" | grep -Fq "${name}.qcow2" || return "$EXIT_POSTCHECK_FAILED"
}
