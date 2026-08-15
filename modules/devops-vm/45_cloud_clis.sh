#!/usr/bin/env bash
set -Eeuo pipefail

vm_cloud_clis_precheck() { assert_scope VM_DEVOPS; }
vm_cloud_clis_plan() {
  cat <<'EOF'
PLAN ONLY:
- install AWS CLI v2 from official AWS distribution with checksum/signature verification where available
- install Azure CLI from official Microsoft repository with repository key verification
- resolve latest supported stable versions during pre-test, record versions in report
- no cloud credentials, profiles or tokens committed to repository
- validate aws --version and az version plus authenticated smoke tests only when user credentials are supplied
EOF
}
vm_cloud_clis_apply() { log_info VM_DEVOPS 'cloud CLI APPLY intentionally disabled during architecture/pre-test phase'; }
vm_cloud_clis_postcheck() { return 0; }
