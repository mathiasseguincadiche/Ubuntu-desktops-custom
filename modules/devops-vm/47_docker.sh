#!/usr/bin/env bash
set -Eeuo pipefail

# scope=VM_DEVOPS. Docker HOST installation is architecturally forbidden.
vm_docker_precheck() {
  assert_scope VM_DEVOPS
  [[ -r "$REPO_ROOT/scripts/devops-vm/install_docker.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_docker_plan() {
  cat <<'EOF'
VM DOCKER PLAN:
- install Docker Engine from Docker's official signed Ubuntu repository
- include containerd, Docker CLI, Buildx and Compose plugin
- grant the VM administration user Docker access inside the guest only
- enable Docker service inside VM_DEVOPS only
- validate daemon, Buildx and Compose remotely
- Docker installation on HOST remains forbidden
EOF
}

vm_docker_apply() {
  local remote='/tmp/ubuntu-desktops-custom-install-docker.sh'
  vm_remote_copy_mutating "$REPO_ROOT/scripts/devops-vm/install_docker.sh" "$remote" || return "$EXIT_APPLY_FAILED"
  vm_remote_prepare || return "$EXIT_APPLY_FAILED"
  vm_remote_run_mutating "sudo bash $remote ${VM_REMOTE_USER}; rc=\$?; sudo rm -f $remote; exit \$rc" || return "$EXIT_APPLY_FAILED"
}

vm_docker_postcheck() {
  if is_true "${DRY_RUN:-true}"; then log_info VM_DEVOPS 'dry-run: Docker postcheck deferred'; return 0; fi
  vm_remote_run_readonly 'sudo docker info >/dev/null && docker buildx version >/dev/null && docker compose version >/dev/null' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
