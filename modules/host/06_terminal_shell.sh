#!/usr/bin/env bash
set -Eeuo pipefail

host_terminal_precheck() {
  assert_scope HOST
  command -v bash >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_terminal_plan() {
  cat <<'EOF'
TERMINAL / BASH PLAN:
- install Ptyxis as preferred GNOME terminal
- install bash-completion and SSH client tooling
- install modern CLI helpers that do not replace core commands: fzf, ripgrep, jq, tree
- preserve Bash as the primary shell
- shell startup customization remains a separate idempotent managed-file step
- every package mutation is executed only through run_mutating
EOF
}

host_terminal_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ptyxis bash-completion openssh-client fzf ripgrep jq tree || return "$EXIT_APPLY_FAILED"
}

host_terminal_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: terminal/shell postcheck deferred'
    return 0
  fi
  command -v bash >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v ssh >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v rg >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v jq >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
