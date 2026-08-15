#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "KVM chain is ordered from preflight to validation" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; module_catalog_validate; printf '%s\n' \"\${CATALOG_ORDER[@]}\""
  [ "$status" -eq 0 ]
  [[ "$output" == *$'kvm.preflight\nkvm.stack\nkvm.firmware\nkvm.storage\nkvm.network\nkvm.catalog\nkvm.cli\nkvm.ssh\nkvm.validation'* ]]
}

@test "every KVM contract exposes four adapter functions" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; for id in \"\${CATALOG_ORDER[@]}\"; do [[ \"\${CATALOG_SCOPE[\$id]}\" == KVM ]] || continue; source \"$REPO_ROOT/\${CATALOG_PATH[\$id]}\"; prefix=\"\${id//./_}\"; declare -F \"\${prefix}_precheck\" >/dev/null; declare -F \"\${prefix}_plan\" >/dev/null; declare -F \"\${prefix}_apply\" >/dev/null; declare -F \"\${prefix}_postcheck\" >/dev/null; done"
  [ "$status" -eq 0 ]
}

@test "KVM modules contain no active package install or libvirt mutation" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get)[[:space:]]+(install|upgrade)|^[[:space:]]*virsh([[:space:]].*)?(net-define|net-start|pool-define|pool-start|define|create)' "$REPO_ROOT/modules/virtualization"
  [ "$status" -ne 0 ]
}

@test "OS catalog pins official Ubuntu 26.04 artifacts" {
  run grep -E 'ubuntu-26\.04-(desktop-amd64\.iso|live-server-amd64\.iso|server-cloudimg-amd64\.img)' "$REPO_ROOT/manifests/virtualization/os-catalog.yml"
  [ "$status" -eq 0 ]
}

@test "KVM validation advertises architecture readiness" {
  run grep -F 'KVM CONTRACT READY' "$REPO_ROOT/modules/virtualization/30_virtualization_validation.sh"
  [ "$status" -eq 0 ]
}
