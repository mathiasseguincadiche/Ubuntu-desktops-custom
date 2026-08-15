#!/usr/bin/env bash
set -Eeuo pipefail

vm_validation_precheck() {
  assert_scope VM_DEVOPS
  if is_true "${DRY_RUN:-true}"; then return 0; fi
  vm_remote_run_readonly 'true' >/dev/null || return "$EXIT_PRECHECK_FAILED"
}

vm_validation_plan() {
  cat <<'EOF'
VM_DEVOPS RUNTIME VALIDATION:
- Ubuntu Server 26.04 identity and cloud-init complete
- expected CPU/RAM contract visible in guest
- stable SSH path on devops-nat
- Git, AWS CLI, Azure CLI, Terraform and Ansible operational
- Docker Engine, Buildx and Compose operational
- kubectl, Helm and kind operational
- ShellCheck, Gitleaks, Trivy, Hadolint and Checkov operational
- no VM_DEVOPS-only tooling is installed by HOST modules

SUCCESS VERDICT:
VM DEVOPS READY
EOF
}

vm_validation_apply() {
  log_info VM_DEVOPS 'validation phase is read-only; no APPLY mutation required'
}

vm_validation_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info VM_DEVOPS 'dry-run: VM runtime validation deferred'
    return 0
  fi

  vm_remote_run_readonly '
    set -eu
    . /etc/os-release
    test "${VERSION_ID}" = "26.04"
    test "$(nproc)" -ge 8
    awk "/MemTotal:/ { exit !(\$2 >= 15000000) }" /proc/meminfo
    cloud-init status --wait >/dev/null
    git --version >/dev/null
    aws --version >/dev/null
    az version >/dev/null
    terraform version >/dev/null
    ansible --version >/dev/null
    sudo docker info >/dev/null
    docker buildx version >/dev/null
    docker compose version >/dev/null
    kubectl version --client >/dev/null
    helm version --short >/dev/null
    kind version >/dev/null
    shellcheck --version >/dev/null
    gitleaks version >/dev/null
    trivy --version >/dev/null
    hadolint --version >/dev/null
    checkov --version >/dev/null
  ' >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
