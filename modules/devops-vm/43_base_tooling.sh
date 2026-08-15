#!/usr/bin/env bash
set -Eeuo pipefail

vm_base_precheck() {
  assert_scope VM_DEVOPS
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_base_plan() {
  cat <<'EOF'
VM BASE TOOLING PLAN:
- wait for cloud-init completion through SSH
- update Ubuntu Server 26.04 package metadata
- install CLI/runtime/network/debug tooling from Ubuntu repositories
- no desktop environment and no HOST DevOps packages
- all guest mutations are transported through vm_remote_run_mutating -> run_mutating
EOF
}

vm_base_apply() {
  vm_remote_run_mutating \
    'sudo cloud-init status --wait && sudo apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install ca-certificates curl wget gnupg jq yq unzip zip tar rsync tree htop tmux make gcc python3 python3-venv pipx dnsutils iproute2 net-tools traceroute tcpdump openssh-client software-properties-common lsb-release' \
    || return "$EXIT_APPLY_FAILED"
}

vm_base_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info VM_DEVOPS 'dry-run: remote base tooling postcheck deferred'
    return 0
  fi
  vm_remote_run_readonly 'command -v curl && command -v jq && command -v yq && command -v python3 && command -v tmux' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
