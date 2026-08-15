#!/usr/bin/env bash
set -Eeuo pipefail

vm_kubernetes_precheck() { assert_scope VM_DEVOPS; }
vm_kubernetes_plan() {
  cat <<'EOF'
PLAN ONLY:
- install kubectl from official Kubernetes packages/repository
- install Helm from official upstream release/repository
- provide kind as the default local Kubernetes lab runtime on top of Docker
- optionally include k9s as an administration convenience after version/source validation
- resolve stable supported versions at pre-test time and record them
- validate kubectl client, helm version, kind cluster lifecycle, DNS, pod/service networking and image pulls
EOF
}
vm_kubernetes_apply() { log_info VM_DEVOPS 'Kubernetes APPLY intentionally disabled during architecture/pre-test phase'; }
vm_kubernetes_postcheck() { return 0; }
