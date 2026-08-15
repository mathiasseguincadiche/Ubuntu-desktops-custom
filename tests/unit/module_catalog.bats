#!/usr/bin/env bats

@test 'module catalog loads the frozen execution order' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    module_catalog_validate
    first="${CATALOG_ORDER[0]}"
    last_index=$((${#CATALOG_ORDER[@]} - 1))
    last="${CATALOG_ORDER[$last_index]}"
    printf "%s|%s|%s\n" "$first" "$last" "${#CATALOG_ORDER[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == host.preflight\|backup.validation\|* ]]
}

@test 'module catalog encodes full HOST chain before KVM' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    printf "%s|%s|%s\n" "${CATALOG_DEPS[host.validation]}" "${CATALOG_DEPS[kvm.preflight]}" "${CATALOG_DEPS[vm.preflight]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "host.gaming|host.validation|kvm.validation" ]
}

@test 'module catalog encodes backup after validated domains' {
  run bash -c '
    source lib/constants.sh
    source lib/scope.sh
    source lib/module_catalog.sh
    REPO_ROOT="$PWD"
    module_catalog_load manifests/module-plan.conf
    printf "%s\n" "${CATALOG_DEPS[backup.preflight]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "host.validation kvm.validation vm.validation" ]
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
    module_catalog_print_plan | grep -F "host.gaming"
    module_catalog_print_plan | grep -F "kvm.network"
  '
  [ "$status" -eq 0 ]
}
