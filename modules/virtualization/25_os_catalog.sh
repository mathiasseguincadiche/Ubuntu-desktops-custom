#!/usr/bin/env bash
set -Eeuo pipefail

kvm_catalog_precheck() { assert_scope KVM; return 0; }
kvm_catalog_plan() {
  cat <<'EOF'
PLAN: maintain a versioned OS catalog with Ubuntu Desktop/Server releases, cloud images, ISO URLs/checksums, architecture, support status and refresh timestamp; downloads remain checksum-verified and disabled in architecture phase.
EOF
}
kvm_catalog_apply() { log_info KVM 'OS catalog download/refresh APPLY disabled during architecture pre-test'; }
kvm_catalog_postcheck() { [[ -r "$REPO_ROOT/manifests/virtualization/os-catalog.yml" ]] || return "$EXIT_POSTCHECK_FAILED"; }
