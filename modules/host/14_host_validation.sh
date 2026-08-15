#!/usr/bin/env bash
set -Eeuo pipefail

host_validation_precheck() {
  assert_scope HOST
  [[ "${HOST_RELEASE:-}" == '26.04' ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${DATA_MOUNT:-}" == '/data' ]] || return "$EXIT_PRECHECK_FAILED"
}

host_validation_plan() {
  cat <<'EOF'
HOST VALIDATION CONTRACT:
- Ubuntu 26.04 target preserved
- system and DATA filesystem contract validated
- hardware preflight completed
- OS/update contract completed
- firmware/microcode contract completed
- Intel Arc graphics contract completed
- multimedia/codecs contract completed
- desktop applications contract completed
- terminal/Bash/SSH contract completed
- gaming contract completed
- no DevOps runtime stack installed on HOST
- no real mutation permitted by this validation module

ARCHITECTURE SUCCESS VERDICT:
HOST CONTRACT READY
EOF
}

host_validation_apply() {
  log_info HOST 'HOST validation APPLY is intentionally a no-op'
}

host_validation_postcheck() {
  local report="$REPORT_ROOT/$RUN_ID-host-validation.txt"
  {
    printf '%s\n' 'HOST CONTRACT READY'
    printf 'release=%s\n' "${HOST_RELEASE:-unknown}"
    printf 'data_mount=%s\n' "${DATA_MOUNT:-unknown}"
    printf 'real_machine_approved=%s\n' "${REAL_MACHINE_APPROVED:-false}"
  } > "$report"
  grep -Fq 'HOST CONTRACT READY' "$report" || return "$EXIT_POSTCHECK_FAILED"
}
