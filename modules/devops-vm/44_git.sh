#!/usr/bin/env bash
set -Eeuo pipefail

vm_git_precheck() { assert_scope VM_DEVOPS; }
vm_git_plan() {
  cat <<'EOF'
PLAN ONLY:
- install Git and OpenSSH client in VM_DEVOPS
- configure user identity only from runtime/user configuration, never hard-code personal identity
- default branch main; safe credential helper policy
- GitHub/GitLab access over SSH using user-provided public/private key material outside repository
- validate clone/fetch/push workflow in pre-test guest
EOF
}
vm_git_apply() { log_info VM_DEVOPS 'Git APPLY intentionally disabled during architecture/pre-test phase'; }
vm_git_postcheck() { return 0; }
