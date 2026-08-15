#!/usr/bin/env bash
set -Eeuo pipefail

vm_identity_ssh_precheck() {
  assert_scope VM_DEVOPS
  [[ "${VM_DEVOPS_ADDRESS_MODE:-}" == "dhcp-reservation" ]] || return "$EXIT_PRECHECK_FAILED"
}

vm_identity_ssh_plan() {
  cat <<'EOF'
PLAN ONLY:
- generate deterministic libvirt MAC identity after collision check
- allocate stable DHCP reservation inside 192.168.50.100-200
- expose guest SSH only to HOST/VM KVM network, never physical LAN/Internet
- use Ed25519 SSH key authentication and disable password authentication after bootstrap
- generate HOST ~/.ssh/config and VS Code Remote SSH target from resolved reservation
EOF
}

vm_identity_ssh_apply() { log_info VM_DEVOPS 'identity/SSH APPLY intentionally disabled during architecture/pre-test phase'; }
vm_identity_ssh_postcheck() { [[ "${VM_DEVOPS_ADDRESS_MODE:-}" == "dhcp-reservation" ]] || return "$EXIT_POSTCHECK_FAILED"; }
