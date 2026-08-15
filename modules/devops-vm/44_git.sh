#!/usr/bin/env bash
set -Eeuo pipefail

vm_git_precheck() {
  assert_scope VM_DEVOPS
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_git_plan() {
  cat <<'EOF'
VM GIT PLAN:
- install Git and OpenSSH client inside VM_DEVOPS only
- set init.defaultBranch=main system-wide
- keep user.name/user.email as runtime user configuration, never repository constants
- keep credentials and private keys outside Git
- validate Git and SSH client availability remotely
EOF
}

vm_git_apply() {
  vm_remote_run_mutating \
    'sudo apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install git openssh-client && sudo git config --system init.defaultBranch main' \
    || return "$EXIT_APPLY_FAILED"
}

vm_git_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: Git postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'git --version && ssh -V 2>&1 && test "$(git config --system --get init.defaultBranch)" = main' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
