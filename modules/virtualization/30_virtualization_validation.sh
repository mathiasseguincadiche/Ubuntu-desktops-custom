#!/usr/bin/env bash
set -Eeuo pipefail

kvm_validation_precheck() { assert_scope KVM; return 0; }
kvm_validation_plan() {
  cat <<'EOF'
VALIDATION: qemu:///system, KVM acceleration, UEFI/TPM capability, storage pools, OS catalog, CLI tools, devops-nat persistence, HOST<->VM, VM<->VM, VM->Internet, DNS, VM->physical-LAN BLOCKED, no unexpected inbound forwarding, SSH/VS Code reachability and idempotence.
EOF
}
kvm_validation_apply() { log_info KVM 'KVM validation APPLY is read-only in architecture phase'; }
kvm_validation_postcheck() {
  [[ "${KVM_NETWORK_READY_REQUIRED:-true}" == true ]] || return "$EXIT_POSTCHECK_FAILED"
  printf '%s\n' 'KVM CONTRACT READY'
}
