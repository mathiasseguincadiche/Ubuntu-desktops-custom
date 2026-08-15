#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "HOST module plan is ordered from preflight to validation" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    module_catalog_validate
    printf '%s\n' \"\${CATALOG_ORDER[@]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *$'host.preflight\nhost.os_updates\nhost.firmware_microcode\nhost.graphics\nhost.multimedia\nhost.apps\nhost.terminal\nhost.gaming\nhost.validation'* ]]
}

@test "every HOST contract exposes four adapter functions" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    for id in \"\${CATALOG_ORDER[@]}\"; do
      [[ \"\${CATALOG_SCOPE[\$id]}\" == HOST ]] || continue
      source \"$REPO_ROOT/\${CATALOG_PATH[\$id]}\"
      prefix=\"\${id//./_}\"
      declare -F \"\${prefix}_precheck\" >/dev/null
      declare -F \"\${prefix}_plan\" >/dev/null
      declare -F \"\${prefix}_apply\" >/dev/null
      declare -F \"\${prefix}_postcheck\" >/dev/null
    done
  "
  [ "$status" -eq 0 ]
}

@test "HOST implementation phase contains no active package install or service mutation" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get)[[:space:]]+(install|upgrade|dist-upgrade|full-upgrade)|^[[:space:]]*(sudo[[:space:]]+)?systemctl[[:space:]]+(enable|disable|start|stop|restart)' "$REPO_ROOT/modules/host"
  [ "$status" -ne 0 ]
}

@test "HOST validation advertises architecture readiness not machine readiness" {
  run grep -F 'HOST CONTRACT READY' "$REPO_ROOT/modules/host/14_host_validation.sh"
  [ "$status" -eq 0 ]
}

@test "DevOps tooling remains outside HOST contracts" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(docker|kubectl|terraform|ansible|aws|az)([[:space:]]|$)' "$REPO_ROOT/modules/host"
  [ "$status" -ne 0 ]
}
