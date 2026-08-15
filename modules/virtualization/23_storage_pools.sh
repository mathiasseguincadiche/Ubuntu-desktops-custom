#!/usr/bin/env bash
set -Eeuo pipefail

kvm_storage_precheck() {
  assert_scope KVM
  [[ "${KVM_POOL_PATH:-}" == /data/* ]] || return "$EXIT_PRECHECK_FAILED"
  if ! is_true "${DRY_RUN:-true}"; then
    [[ "$(findmnt -n -o FSTYPE /data 2>/dev/null || true)" == ext4 ]] || return "$EXIT_PRECHECK_FAILED"
    command -v virsh >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  fi
}

kvm_storage_plan() {
  cat <<'EOF'
KVM STORAGE PLAN:
- create /data/libvirt/images on the dedicated DATA EXT4 filesystem
- define a directory libvirt pool named devops-data on qemu:///system
- start and autostart the pool idempotently
- qcow2 volumes remain sparse and are created by VM provisioning modules
- never place managed VM disks on the HOST system filesystem when DATA is available
- every mutation is executed only through run_mutating
EOF
}

kvm_storage_apply() {
  local pool="${KVM_POOL_NAME:-devops-data}"
  local path="${KVM_POOL_PATH:-/data/libvirt/images}"

  run_mutating KVM sudo install -d -m 0750 "$path" || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-define-as "$pool" dir --target "$path" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-start "$pool" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-autostart "$pool" || return "$EXIT_APPLY_FAILED"
    return 0
  fi

  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" >/dev/null 2>&1; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-define-as "$pool" dir --target "$path" || return "$EXIT_APPLY_FAILED"
  fi
  if [[ "$(sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" | awk -F: '/State/{gsub(/^[ \t]+/,"",$2); print $2}')" != running ]]; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-start "$pool" || return "$EXIT_APPLY_FAILED"
  fi
  run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-autostart "$pool" || return "$EXIT_APPLY_FAILED"
}

kvm_storage_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: libvirt storage postcheck deferred'
    return 0
  fi
  [[ "$(findmnt -n -o FSTYPE /data)" == ext4 ]] || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "${KVM_POOL_NAME:-devops-data}" | grep -Eq '^State:[[:space:]]+running' || return "$EXIT_POSTCHECK_FAILED"
}
