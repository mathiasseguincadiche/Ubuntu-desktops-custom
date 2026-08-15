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

vm_provision_rollback() {
  local uri="$1" network="$2" name="$3" disk="$4" mac="$5" ip="$6" reservation_added="$7"
  local failed=0 state

  log_warn VM_DEVOPS "rolling back incomplete provisioning for $name"

  if sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1; then
    state="$(sudo virsh --connect "$uri" domstate "$name" 2>/dev/null || true)"
    if [[ "$state" == running || "$state" == paused || "$state" == 'in shutdown' ]]; then
      run_mutating VM_DEVOPS sudo virsh --connect "$uri" destroy "$name" || failed=1
    fi
    run_mutating VM_DEVOPS sudo virsh --connect "$uri" undefine "$name" --nvram || \
      run_mutating VM_DEVOPS sudo virsh --connect "$uri" undefine "$name" || failed=1
  fi

  if [[ "$reservation_added" == true ]]; then
    run_mutating VM_DEVOPS sudo virsh --connect "$uri" net-update "$network" delete ip-dhcp-host \
      "<host mac='$mac' name='$name' ip='$ip'/>" --live --config || failed=1
  fi

  if [[ -e "$disk" ]]; then
    run_mutating VM_DEVOPS sudo rm -f -- "$disk" || failed=1
  fi

  (( failed == 0 ))
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
- rollback a newly-created disk, DHCP reservation and partial libvirt domain if provisioning fails
- every mutation is executed only through run_mutating
EOF
}

vm_provision_apply() {
  local packed base disk seed identity mac ip
  local reservation_added=false
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

  if ! run_mutating VM_DEVOPS sudo cp --reflink=auto --sparse=always "$base" "$disk"; then
    return "$EXIT_APPLY_FAILED"
  fi
  if ! run_mutating VM_DEVOPS sudo qemu-img resize "$disk" "${VM_DEVOPS_DISK_GB:-200}G"; then
    if ! is_true "${DRY_RUN:-true}"; then
      vm_provision_rollback "$uri" "$network" "$name" "$disk" "$mac" "$ip" false || return "$EXIT_ROLLBACK_FAILED"
    fi
    return "$EXIT_APPLY_FAILED"
  fi

  if is_true "${DRY_RUN:-true}"; then
    run_mutating VM_DEVOPS sudo virsh --connect "$uri" net-update "$network" add ip-dhcp-host \
      "<host mac='$mac' name='$name' ip='$ip'/>" --live --config || return "$EXIT_APPLY_FAILED"
  else
    local xml
    xml="$(sudo virsh --connect "$uri" net-dumpxml "$network")" || {
      vm_provision_rollback "$uri" "$network" "$name" "$disk" "$mac" "$ip" false || return "$EXIT_ROLLBACK_FAILED"
      return "$EXIT_APPLY_FAILED"
    }
    if ! grep -Fiq "mac='$mac'" <<< "$xml"; then
      if ! run_mutating VM_DEVOPS sudo virsh --connect "$uri" net-update "$network" add ip-dhcp-host \
        "<host mac='$mac' name='$name' ip='$ip'/>" --live --config; then
        vm_provision_rollback "$uri" "$network" "$name" "$disk" "$mac" "$ip" false || return "$EXIT_ROLLBACK_FAILED"
        return "$EXIT_APPLY_FAILED"
      fi
      reservation_added=true
    fi
  fi

  if ! run_mutating VM_DEVOPS sudo virt-install \
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
    --noautoconsole; then
    if ! is_true "${DRY_RUN:-true}"; then
      vm_provision_rollback "$uri" "$network" "$name" "$disk" "$mac" "$ip" "$reservation_added" || return "$EXIT_ROLLBACK_FAILED"
    fi
    return "$EXIT_APPLY_FAILED"
  fi
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
