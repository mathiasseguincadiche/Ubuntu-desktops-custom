#!/usr/bin/env bash
set -Eeuo pipefail

vm_iac_precheck() { assert_scope VM_DEVOPS; }
vm_iac_plan() {
  cat <<'EOF'
PLAN ONLY:
- install Terraform from official HashiCorp repository/signing key
- install Ansible from supported Ubuntu/Python packaging selected by pre-test
- include ansible-core tooling and common lint/validation helpers without global pip pollution
- resolve supported stable versions at pre-test time and persist them in the execution report
- validate terraform version, terraform fmt/validate and ansible --version/ansible-lint smoke tests
EOF
}
vm_iac_apply() { log_info VM_DEVOPS 'IaC APPLY intentionally disabled during architecture/pre-test phase'; }
vm_iac_postcheck() { return 0; }
