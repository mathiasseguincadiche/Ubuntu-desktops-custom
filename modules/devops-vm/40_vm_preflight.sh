#!/usr/bin/env bash
set -Eeuo pipefail

vm_preflight_precheck() {
  assert_scope VM_DEVOPS
  [[ "${VM_DEVOPS_NAME:-}" == "ubuntu-devops" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${VM_DEVOPS_NETWORK:-}" == "devops-nat" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${VM_DEVOPS_RAM_MB:-0}" -ge 8192 ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${VM_DEVOPS_VCPU:-0}" -ge 4 ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${VM_DEVOPS_DISK_GB:-0}" -ge 100 ]] || return "$EXIT_PRECHECK_FAILED"
}

vm_preflight_plan() {
  cat <<'EOF'
PLAN ONLY:
- Ubuntu Server 26.04 LTS cloud image verified by checksum/signature before use
- ubuntu-devops sizing: 8 vCPU, 16 GiB RAM, 200 GiB qcow2
- attach only to libvirt devops-nat
- guest remains DHCP client; stable address comes from libvirt DHCP reservation
- SSH key authentication only; no repository-stored credentials
- DevOps tooling belongs exclusively to VM_DEVOPS, never HOST
EOF
}

vm_preflight_apply() {
  log_info VM_DEVOPS 'VM preflight APPLY intentionally disabled during architecture/pre-test phase'
}

vm_preflight_postcheck() {
  [[ "${VM_DEVOPS_NETWORK:-}" == "devops-nat" ]] || return "$EXIT_POSTCHECK_FAILED"
}
