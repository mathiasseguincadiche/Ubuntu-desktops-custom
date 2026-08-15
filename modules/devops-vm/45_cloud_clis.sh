#!/usr/bin/env bash
set -Eeuo pipefail

vm_cloud_clis_precheck() {
  assert_scope VM_DEVOPS
  [[ -r "$REPO_ROOT/scripts/devops-vm/install_cloud_clis.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_cloud_clis_plan() {
  cat <<'EOF'
VM CLOUD CLI PLAN:
- install AWS CLI v2 from the official AWS installer downloaded to disk first
- install Azure CLI from the Microsoft signed repository
- on Ubuntu 26.04, use the Microsoft-documented Ubuntu jammy fallback repository policy
- never pipe remote downloads directly into a shell
- keep cloud credentials, profiles and tokens outside the repository
- validate aws --version and az version remotely
EOF
}

vm_cloud_clis_apply() {
  local remote='/tmp/ubuntu-desktops-custom-install-cloud-clis.sh'
  vm_remote_copy_mutating "$REPO_ROOT/scripts/devops-vm/install_cloud_clis.sh" "$remote" || return "$EXIT_APPLY_FAILED"
  vm_remote_run_mutating "sudo env AZURE_CLI_REPO_FALLBACK=${AZURE_CLI_REPO_FALLBACK:-jammy} bash $remote; rc=\$?; sudo rm -f $remote; exit \$rc" || return "$EXIT_APPLY_FAILED"
}

vm_cloud_clis_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: cloud CLI postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'aws --version && az version >/dev/null' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
