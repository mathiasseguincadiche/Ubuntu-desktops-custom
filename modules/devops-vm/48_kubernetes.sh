#!/usr/bin/env bash
set -Eeuo pipefail

vm_kubernetes_precheck() {
  assert_scope VM_DEVOPS
  [[ -r "$REPO_ROOT/scripts/devops-vm/install_kubernetes.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'sudo docker info >/dev/null' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_kubernetes_plan() {
  cat <<'EOF'
VM KUBERNETES PLAN:
- install kubectl from dl.k8s.io and verify the published SHA-256
- install Helm from the official signed Helm apt repository
- install kind from its official release and verify SHA-256
- use Docker inside VM_DEVOPS as the local Kubernetes runtime
- validate CLI versions without creating a persistent cluster during installation
EOF
}

vm_kubernetes_apply() {
  local remote='/tmp/ubuntu-desktops-custom-install-kubernetes.sh'
  vm_remote_copy_mutating "$REPO_ROOT/scripts/devops-vm/install_kubernetes.sh" "$remote" || return "$EXIT_APPLY_FAILED"
  vm_remote_run_mutating "sudo bash $remote; rc=\$?; sudo rm -f $remote; exit \$rc" || return "$EXIT_APPLY_FAILED"
}

vm_kubernetes_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: Kubernetes postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'kubectl version --client >/dev/null && helm version --short >/dev/null && kind version >/dev/null' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
