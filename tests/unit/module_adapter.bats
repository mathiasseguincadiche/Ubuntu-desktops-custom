#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "adapter registers implemented HOST preflight contract" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/orchestrator.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; source '$REPO_ROOT/lib/module_adapter.sh'
    export REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; module_catalog_validate
    module_adapter_register host.preflight
    [[ \"\${ORCH_SCOPE[host.preflight]}\" == HOST ]]
  "
  [ "$status" -eq 0 ]
}

@test "adapter registers implemented HOST validation contract" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/orchestrator.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; source '$REPO_ROOT/lib/module_adapter.sh'
    export REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; module_catalog_validate
    module_adapter_register host.validation
    [[ \"\${ORCH_POSTCHECK[host.validation]}\" == host_validation_postcheck ]]
  "
  [ "$status" -eq 0 ]
}

@test "adapter registers implemented KVM network contract" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/orchestrator.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; source '$REPO_ROOT/lib/module_adapter.sh'
    export REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; module_catalog_validate
    module_adapter_register kvm.network
    [[ \"\${ORCH_SCOPE[kvm.network]}\" == KVM ]]
    [[ \"\${ORCH_APPLY[kvm.network]}\" == kvm_network_apply ]]
  "
  [ "$status" -eq 0 ]
}
