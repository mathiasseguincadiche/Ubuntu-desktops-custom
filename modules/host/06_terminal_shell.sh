#!/usr/bin/env bash
set -Eeuo pipefail

host_terminal_precheck() {
  assert_scope HOST
  command -v bash >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_terminal_plan() {
  cat <<'EOF'
PLAN ONLY:
- Ptyxis as the preferred graphical terminal when available/compatible
- Bash completion, programmable completion and modern CLI ergonomics
- safe prompt/history defaults without replacing Bash as the primary shell
- CLI helpers only when they do not shadow core commands unexpectedly
- preserve SSH client tooling required for VM administration
- validate shell startup files for idempotence and non-interactive compatibility
EOF
}

host_terminal_apply() {
  log_info HOST 'terminal/shell APPLY intentionally disabled during pre-test architecture phase'
}

host_terminal_postcheck() {
  command -v bash >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
