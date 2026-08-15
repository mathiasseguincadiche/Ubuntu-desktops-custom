#!/usr/bin/env bash
set -Eeuo pipefail

kvm_stack_precheck() { assert_scope KVM; return 0; }
kvm_stack_plan() {
  cat <<'EOF'
PLAN: QEMU/KVM, libvirt system daemon/socket model, qemu:///system, virt-install, virsh, virt-host-validate and virt-manager as optional GUI only.
EOF
}
kvm_stack_apply() { log_info KVM 'QEMU/libvirt APPLY disabled during architecture pre-test'; }
kvm_stack_postcheck() { return 0; }
