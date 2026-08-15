#!/usr/bin/env bash
set -Eeuo pipefail

vm_cloud_init_precheck() {
  assert_scope VM_DEVOPS
  [[ -f "${REPO_ROOT}/virtualization/cloud-init/user-data.tpl" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -f "${REPO_ROOT}/virtualization/cloud-init/network-config.tpl" ]] || return "$EXIT_PRECHECK_FAILED"
}

vm_cloud_init_plan() {
  cat <<'EOF'
PLAN ONLY:
- render NoCloud seed from versioned templates
- set hostname ubuntu-devops
- create non-root administration user from runtime configuration
- inject SSH public key at runtime only
- enable OpenSSH server, qemu-guest-agent and unattended security updates
- keep guest networking on DHCP; no static IP in netplan
- never store passwords, private keys or cloud credentials in Git
EOF
}

vm_cloud_init_apply() {
  log_info VM_DEVOPS 'cloud-init APPLY intentionally disabled during architecture/pre-test phase'
}

vm_cloud_init_postcheck() {
  grep -F 'dhcp4: true' "${REPO_ROOT}/virtualization/cloud-init/network-config.tpl" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}
