#!/usr/bin/env bash
set -Eeuo pipefail

# scope=VM_DEVOPS. Docker HOST installation is architecturally forbidden.
vm_docker_precheck() { assert_scope VM_DEVOPS; }
vm_docker_plan() {
  cat <<'EOF'
PLAN ONLY:
- install Docker Engine from official Docker repository
- include containerd, Docker CLI, Buildx and Compose plugin
- configure non-root Docker access for the VM administration user after security review
- configure log rotation and sane daemon defaults
- validate hello-world, buildx, compose and container networking
- Docker installation on HOST remains forbidden by architecture
EOF
}
vm_docker_apply() { log_info VM_DEVOPS 'Docker APPLY intentionally disabled during architecture/pre-test phase'; }
vm_docker_postcheck() { return 0; }
