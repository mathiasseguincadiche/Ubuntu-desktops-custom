#!/usr/bin/env bash
set -Eeuo pipefail

kvm_cli_precheck() { assert_scope KVM; return 0; }
kvm_cli_plan() {
  cat <<'EOF'
PLAN: CLI-first administration with virsh/virt-install/virt-clone/qemu-img; virt-manager remains optional GUI fallback. Include list/start/shutdown/destroy/autostart/dominfo/domifaddr/snapshot/clone/pool/volume/network commands in beginner guide.
EOF
}
kvm_cli_apply() { log_info KVM 'CLI management APPLY disabled during architecture pre-test'; }
kvm_cli_postcheck() { return 0; }
