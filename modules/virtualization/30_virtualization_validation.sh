#!/usr/bin/env bash
set -Eeuo pipefail

# Scope: KVM
# Validation contract only. No network modification.
MODULE_ID="30_virtualization_validation"
MODULE_SCOPE="KVM"

module_validation_plan() {
  cat <<'EOF'
KVM VALIDATION CONTRACT:
- qemu:///system reachable
- devops-nat defined, active and configured for autostart
- virbr50 = 192.168.50.254/24
- DHCP pool = 192.168.50.100-200
- configured DNS contract validated
- HOST -> VM = PASS
- VM -> HOST = PASS
- VM -> VM = PASS
- VM -> Internet = PASS
- VM -> physical LAN = BLOCKED (proven against a known reachable LAN target)
- unexpected inbound DNAT/port forwarding = NONE
- existing HOST firewall remains healthy
- isolation rules are idempotent (no duplicate project rules)
- reboot persistence validated during final pre-test

SUCCESS VERDICT (only when every required check passes):
KVM NETWORK READY
EOF
}
