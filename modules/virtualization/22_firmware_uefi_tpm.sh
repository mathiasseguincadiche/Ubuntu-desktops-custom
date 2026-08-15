#!/usr/bin/env bash
set -Eeuo pipefail

kvm_firmware_precheck() { assert_scope KVM; return 0; }
kvm_firmware_plan() {
  cat <<'EOF'
PLAN: OVMF/UEFI firmware inventory, Secure Boot capable firmware where required, swtpm/TPM 2.0 support and per-VM firmware policy.
EOF
}
kvm_firmware_apply() { log_info KVM 'UEFI/TPM APPLY disabled during architecture pre-test'; }
kvm_firmware_postcheck() { return 0; }
