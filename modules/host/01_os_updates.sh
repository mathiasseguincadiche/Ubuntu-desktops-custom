#!/usr/bin/env bash
set -Eeuo pipefail

host_os_updates_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v dpkg >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_os_updates_plan() {
  cat <<'EOF'
PLAN ONLY:
- refresh Ubuntu package metadata
- apply supported Ubuntu 26.04 updates
- preserve release/channel configuration
- detect reboot-required state
- never perform release-upgrade implicitly
EOF
}

host_os_updates_apply() {
  log_info HOST 'OS update APPLY intentionally disabled during pre-test architecture phase'
}

host_os_updates_postcheck() {
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
