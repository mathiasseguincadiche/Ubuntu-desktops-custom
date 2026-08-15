#!/usr/bin/env bash
set -Eeuo pipefail

# Scope: KVM
# Architecture-only stub. No network/firewall changes are permitted yet.
MODULE_ID="24_networks"
MODULE_SCOPE="KVM"
MODULE_STATUS="BLOCKED"

module_precheck() {
  cat <<'EOF'
PRECHECK CONTRACT:
- inventory active HOST interfaces and routes
- reject overlap between 192.168.50.0/24 and any existing connected route
- identify physical LAN networks dynamically; do not hard-code them
- validate qemu:///system and planned virbr50 availability
- validate that DHCP range and gateway do not conflict
- snapshot relevant existing libvirt/firewall state for targeted rollback
EOF
}

module_plan() {
  cat <<'EOF'
PLAN ONLY:
- validate libvirt qemu:///system
- define devops-nat with virbr50 and HOST/gateway 192.168.50.254
- configure DHCP 192.168.50.100-200
- configure DNS contract 9.9.9.9 and 1.1.1.1
- keep guests as DHCP clients; stable VM identities use conflict-checked DHCP reservations
- preserve HOST <-> VM and VM <-> VM communication
- allow VM -> Internet through NAT
- explicitly block VM -> dynamically detected physical LAN networks
- preserve the existing HOST firewall; never flush nftables/iptables globally
- block inbound LAN/Internet -> VM by default
- run connectivity and isolation postchecks
- rollback only project-owned network/firewall changes if validation fails
EOF
}

module_apply() {
  printf '%s\n' "BLOCKED: network apply is disabled until PRE-TEST READY and REAL_MACHINE_APPROVED=true." >&2
  return 8
}

module_postcheck() {
  printf '%s\n' "No postcheck: apply is intentionally blocked."
}
