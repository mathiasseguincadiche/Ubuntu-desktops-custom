#!/usr/bin/env bash
set -Eeuo pipefail

# Scope: KVM
# Architecture-only preflight contract. Read-only checks only.
MODULE_ID="20_preflight_kvm"
MODULE_SCOPE="KVM"

module_precheck_plan() {
  cat <<'EOF'
READ-ONLY KVM PREFLIGHT CONTRACT:
- verify Ubuntu 26.04 / architecture
- verify AMD-V/SVM and /dev/kvm
- verify qemu:///system availability when libvirt exists
- inventory ip -4 route and ip -4 addr
- ensure 192.168.50.0/24 is not already routed/connected outside planned devops-nat
- inventory existing virbr*/libvirt networks
- ensure virbr50 and devops-nat do not conflict
- inventory firewall backend/state without modifying it
- verify required commands when implementation dependencies are installed
- produce BLOCKED / MANUAL_ACTION_REQUIRED on ambiguous network overlap
EOF
}
