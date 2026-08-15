#!/usr/bin/env bash
set -Eeuo pipefail

kvm_ssh_precheck() { assert_scope KVM; return 0; }
kvm_ssh_plan() {
  cat <<'EOF'
PLAN: HOST->VM SSH over devops-nat, deterministic DHCP reservation, known_hosts hygiene, key-based authentication and VS Code Remote SSH to Ubuntu Server 26.04; no exposure to physical LAN or Internet.
EOF
}
kvm_ssh_apply() { log_info KVM 'SSH access APPLY disabled during architecture pre-test'; }
kvm_ssh_postcheck() { return 0; }
