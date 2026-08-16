#!/usr/bin/env bash
set -Eeuo pipefail

kvm_catalog_runtime_file() {
  printf '%s\n' "$REPO_ROOT/state/kvm/os-catalog.resolved"
}

kvm_catalog_precheck() {
  assert_scope KVM
  [[ -r "$REPO_ROOT/manifests/virtualization/os-catalog.yml" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/kvm/refresh_os_catalog.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  command -v awk >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"

  # curl is installed earlier by host.apps during a real APPLY. A full dry-run
  # intentionally does not mutate the HOST, so absence of curl at this point
  # must not create a false dependency failure. The catalog refresh itself is
  # also simulated by run_mutating in dry-run mode.
  if ! command -v curl >/dev/null 2>&1; then
    if is_true "${DRY_RUN:-true}"; then
      log_info KVM 'dry-run: curl runtime requirement deferred; host.apps would install it before real KVM catalog refresh'
      return 0
    fi
    return "$EXIT_PRECHECK_FAILED"
  fi
}

kvm_catalog_plan() {
  cat <<'EOF'
OS CATALOG PLAN:
- keep manifests/virtualization/os-catalog.yml as the immutable canonical definition
- query only the configured official Canonical SHA256SUMS sources
- resolve every configured Ubuntu Desktop/Server/cloud artifact to a current SHA256
- write the verified runtime view to state/kvm/os-catalog.resolved
- never download an OS image during catalog refresh
- every runtime write remains behind run_mutating
EOF
}

kvm_catalog_apply() {
  run_mutating KVM bash "$REPO_ROOT/scripts/kvm/refresh_os_catalog.sh" || return "$EXIT_APPLY_FAILED"
}

kvm_catalog_postcheck() {
  local runtime
  runtime="$(kvm_catalog_runtime_file)"
  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: OS catalog runtime verification deferred'
    return 0
  fi

  [[ -r "$runtime" ]] || return "$EXIT_POSTCHECK_FAILED"
  grep -Fx 'status=verified' "$runtime" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  grep -F 'artifact=ubuntu-26.04-desktop-amd64.iso|sha256=' "$runtime" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  grep -F 'artifact=ubuntu-26.04-live-server-amd64.iso|sha256=' "$runtime" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  grep -F 'artifact=ubuntu-26.04-server-cloudimg-amd64.img|sha256=' "$runtime" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  log_info KVM "verified OS catalog runtime: $runtime"
}
