#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "adapter registers implemented HOST preflight contract" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/orchestrator.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    source '$REPO_ROOT/lib/module_adapter.sh'
    export REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    module_catalog_validate
    module_adapter_register host.preflight
    [[ \"\${ORCH_SCOPE[host.preflight]}\" == HOST ]]
    [[ \"\${ORCH_PRECHECK[host.preflight]}\" == host_preflight_precheck ]]
  "
  [ "$status" -eq 0 ]
}

@test "adapter rejects placeholder module without full contract" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/orchestrator.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    source '$REPO_ROOT/lib/module_adapter.sh'
    export REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    module_catalog_validate
    module_adapter_register host.validation
  "
  [ "$status" -eq 2 ]
}
