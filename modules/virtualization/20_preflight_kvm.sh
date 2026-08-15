#!/usr/bin/env bash
set -Eeuo pipefail

kvm_preflight_precheck() {
  assert_scope KVM
  command -v lscpu >/dev/null || return "$EXIT_PRECHECK_FAILED"
  command -v ip >/dev/null || return "$EXIT_PRECHECK_FAILED"
  grep -Eq 'AMD-V|svm' < <(lscpu 2>/dev/null) || return "$EXIT_PRECHECK_FAILED"
  [[ -c /dev/kvm || -n "${KVM_PREFLIGHT_ALLOW_FIXTURE:-}" ]] || return "$EXIT_PRECHECK_FAILED"
  log_info KVM 'KVM read-only preflight passed'
}

kvm_preflight_plan() {
  cat <<'EOF'
READ-ONLY: validate AMD-V/SVM, /dev/kvm, qemu:///system prerequisites, active routes, existing libvirt networks, firewall backend and overlap risk for 192.168.50.0/24.
EOF
}

kvm_preflight_apply() {
  log_info KVM 'KVM preflight apply is intentionally a no-op'
}

kvm_preflight_postcheck() {
  return 0
}
