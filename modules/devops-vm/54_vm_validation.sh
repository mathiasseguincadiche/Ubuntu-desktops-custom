#!/usr/bin/env bash
set -Eeuo pipefail

vm_validation_precheck() {
  assert_scope VM_DEVOPS
}

vm_validation_plan() {
  cat <<'EOF'
VM_DEVOPS VALIDATION CONTRACT:
- Ubuntu Server 26.04 LTS identity and cloud-init completed
- 8 vCPU / 16 GiB RAM / 200 GiB disk contract satisfied
- stable DHCP reservation on devops-nat
- HOST -> VM SSH and VS Code Remote SSH path validated
- VM -> Internet and DNS validated; VM -> physical LAN remains blocked by KVM policy
- Git operational
- AWS CLI and Azure CLI operational
- Terraform and Ansible operational
- Docker Engine + Buildx + Compose operational
- kubectl + Helm + kind operational
- DevSecOps smoke tests operational
- no VM_DEVOPS-only tooling installed by HOST modules

SUCCESS VERDICT (architecture/pre-test contract only):
VM DEVOPS CONTRACT READY
EOF
}

vm_validation_apply() { log_info VM_DEVOPS 'VM validation APPLY intentionally disabled during architecture/pre-test phase'; }
vm_validation_postcheck() { return 0; }
