#!/usr/bin/env bash
set -Eeuo pipefail

vm_devsecops_precheck() {
  assert_scope VM_DEVOPS
  [[ -r "$REPO_ROOT/scripts/devops-vm/install_devsecops.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_devsecops_plan() {
  cat <<'EOF'
VM DEVSECOPS PLAN:
- install ShellCheck from Ubuntu repositories
- install Gitleaks, Trivy and Hadolint from official GitHub releases with published SHA-256 verification
- install Checkov in an isolated pipx environment
- keep scan outputs and credentials outside source control by default
- validate all installed scanners remotely
EOF
}

vm_devsecops_apply() {
  local remote='/tmp/ubuntu-desktops-custom-install-devsecops.sh'
  vm_remote_copy_mutating "$REPO_ROOT/scripts/devops-vm/install_devsecops.sh" "$remote" || return "$EXIT_APPLY_FAILED"
  vm_remote_run_mutating "sudo bash $remote; rc=\$?; sudo rm -f $remote; exit \$rc" || return "$EXIT_APPLY_FAILED"
}

vm_devsecops_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: DevSecOps postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'shellcheck --version >/dev/null && gitleaks version >/dev/null && trivy --version >/dev/null && hadolint --version >/dev/null && checkov --version >/dev/null' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
