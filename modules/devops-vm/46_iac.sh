#!/usr/bin/env bash
set -Eeuo pipefail

vm_iac_precheck() {
  assert_scope VM_DEVOPS
  [[ -r "$REPO_ROOT/scripts/devops-vm/install_iac.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_iac_plan() {
  cat <<'EOF'
VM IAC PLAN:
- install Terraform from the official HashiCorp signed apt repository
- install ansible-core and ansible-lint from Ubuntu Server repositories
- keep Python system packages unpolluted by arbitrary global pip installs
- record resolved versions through postcheck/reporting
- all mutations are transported through scoped VM SSH
EOF
}

vm_iac_apply() {
  local remote='/tmp/ubuntu-desktops-custom-install-iac.sh'
  vm_remote_copy_mutating "$REPO_ROOT/scripts/devops-vm/install_iac.sh" "$remote" || return "$EXIT_APPLY_FAILED"
  vm_remote_run_mutating "sudo bash $remote; rc=\$?; sudo rm -f $remote; exit \$rc" || return "$EXIT_APPLY_FAILED"
}

vm_iac_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: IaC postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'terraform version >/dev/null && ansible --version >/dev/null && ansible-lint --version >/dev/null' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
