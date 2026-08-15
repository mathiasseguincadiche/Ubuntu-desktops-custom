#!/usr/bin/env bats

@test 'module catalog loads the frozen execution order' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    module_catalog_validate
    printf "%s\n" "${CATALOG_ORDER[@]}"
  '
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = host.preflight ]
  [ "${lines[9]}" = backup.validation ]
}

@test 'module catalog encodes KVM before VM DEVOPS and backup last' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    printf "%s|%s|%s\n" "${CATALOG_DEPS[kvm.network]}" "${CATALOG_DEPS[vm.preflight]}" "${CATALOG_DEPS[backup.preflight]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "kvm.preflight|kvm.validation|host.validation kvm.validation vm.validation" ]
}

@test 'module catalog rejects path outside modules tree' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    tmp="$(mktemp)"
    printf "evil|HOST||../../etc/passwd\n" > "$tmp"
    module_catalog_load "$tmp"
  '
  [ "$status" -ne 0 ]
}

@test 'module catalog plan is read only metadata' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    module_catalog_validate
    module_catalog_print_plan | grep -F "kvm.network"
  '
  [ "$status" -eq 0 ]
}
