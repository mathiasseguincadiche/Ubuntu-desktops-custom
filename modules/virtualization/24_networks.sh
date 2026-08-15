#!/usr/bin/env bash
set -Eeuo pipefail

# Scope: KVM
# Architecture-only stub. No network/firewall changes are permitted yet.
MODULE_ID="24_networks"
MODULE_SCOPE="KVM"
MODULE_STATUS="BLOCKED"

module_precheck() {
  printf '%s\n' "KVM network contract: devops-nat / 192.168.50.0/24 / gateway 192.168.50.254"
}

module_plan() {
  cat <<'EOF'
PLAN ONLY:
- validate libvirt qemu:///system
- validate that 192.168.50.0/24 does not conflict with host routes
- define devops-nat with virbr50 and gateway 192.168.50.254
- configure DHCP 192.168.50.100-200
- configure DNS forwarders 9.9.9.9 and 1.1.1.1
- preserve HOST <-> VM and VM <-> VM communication
- allow VM -> Internet through NAT
- explicitly block VM -> physical LAN without flushing existing firewall rules
- block inbound LAN/Internet -> VM by default
- run connectivity and isolation postchecks
EOF
}

module_apply() {
  printf '%s\n' "BLOCKED: network apply is disabled until PRE-TEST READY and REAL_MACHINE_APPROVED=true." >&2
  return 8
}

module_postcheck() {
  printf '%s\n' "No postcheck: apply is intentionally blocked."
}
