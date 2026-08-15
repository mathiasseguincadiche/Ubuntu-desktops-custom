#!/usr/bin/env bash
set -Eeuo pipefail

host_os_updates_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v dpkg >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_os_updates_plan() {
  cat <<'EOF'
HOST OS UPDATE PLAN:
- refresh Ubuntu package metadata
- apply supported Ubuntu 26.04 updates with apt-get full-upgrade
- preserve the current LTS release/channel configuration
- never invoke do-release-upgrade implicitly
- detect reboot-required state after package convergence
- every mutation is executed only through run_mutating
EOF
}

host_os_updates_apply() {
  run_mutating HOST sudo apt-get update || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade || return "$EXIT_APPLY_FAILED"
}

host_os_updates_postcheck() {
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: package convergence postcheck deferred'
    return 0
  fi
  run_readonly HOST apt-get -s upgrade >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  if [[ -f /var/run/reboot-required ]]; then
    log_warn HOST 'reboot required after OS update convergence'
  fi
}
