#!/usr/bin/env bash
set -Eeuo pipefail

kvm_network_precheck() {
  assert_scope KVM
  log_info KVM 'network precheck is read-only and fail-closed'
}

kvm_network_plan() {
  cat <<'EOF'
PLAN: devops-nat on 192.168.50.0/24, virbr50/192.168.50.254, DHCP .100-.200, DNS 9.9.9.9 + 1.1.1.1, HOST<->VM and VM<->VM allowed, VM->Internet NAT allowed, VM->physical-LAN blocked, no inbound forwarding, targeted rollback and reboot persistence validation.
EOF
}

kvm_network_apply() {
  printf '%s\n' 'BLOCKED: KVM network mutation remains disabled until PRE-TEST READY and explicit real-machine approval.' >&2
  return "$EXIT_SECURITY_BLOCK"
}

kvm_network_postcheck() {
  [[ "${KVM_FAIL_CLOSED:-true}" == true ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "${KVM_NETWORK_CIDR:-}" == '192.168.50.0/24' ]] || return "$EXIT_POSTCHECK_FAILED"
}
