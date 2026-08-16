#!/usr/bin/env bash
set -Eeuo pipefail

kvm_stack_operator() {
  local operator="${SUDO_USER:-${USER:-}}"
  [[ -n "$operator" && "$operator" != root ]] || return "$EXIT_PRECHECK_FAILED"
  printf '%s\n' "$operator"
}

kvm_stack_has_intel_render_node() {
  local node sysfs vendor
  shopt -s nullglob
  local nodes=(/dev/dri/renderD*)
  shopt -u nullglob
  for node in "${nodes[@]}"; do
    sysfs="/sys/class/drm/$(basename "$node")/device"
    [[ -r "$sysfs/vendor" ]] || continue
    vendor="$(<"$sysfs/vendor")"
    [[ "${vendor,,}" == '0x8086' ]] && return 0
  done
  return 1
}

kvm_stack_precheck() {
  assert_scope KVM
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -e /dev/kvm ]] || [[ "${DRY_RUN:-true}" == true ]] || return "$EXIT_PRECHECK_FAILED"
  kvm_stack_operator >/dev/null
}

kvm_stack_plan() {
  cat <<'EOF'
QEMU / LIBVIRT STACK PLAN:
- install QEMU x86 system emulator and qemu-img utilities
- install libvirt system daemon and clients for qemu:///system
- install virt-install/virt-manager/virt-viewer; CLI remains the primary administration path
- install SPICE guest-display tooling, swtpm and virgl/virtio-gpu support for optional desktop guests
- install osinfo-db for libvirt/virt-install guest OS metadata
- grant the interactive operator membership in libvirt and kvm groups
- package/service setup remains distribution-managed; no custom daemon replacement
- every mutation is executed only through run_mutating
EOF
}

kvm_stack_apply() {
  local operator
  operator="$(kvm_stack_operator)" || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    qemu-system-x86 qemu-utils \
    libvirt-daemon-system libvirt-clients \
    virt-install virt-manager virt-viewer \
    spice-client-gtk swtpm swtpm-tools libvirglrenderer1 osinfo-db || return "$EXIT_APPLY_FAILED"
  run_mutating KVM sudo usermod -aG libvirt,kvm "$operator" || return "$EXIT_APPLY_FAILED"
}

kvm_stack_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: QEMU/libvirt postcheck deferred'
    return 0
  fi
  command -v virsh >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v qemu-img >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v virt-install >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v virt-manager >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v virt-viewer >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v swtpm >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  kvm_stack_has_intel_render_node || log_warn KVM 'Intel DRM render node absent: accelerated Ubuntu Desktop guest profile will require review'
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  log_warn KVM 'operator group membership may require logout/login before non-sudo libvirt access is available'
}
