#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "diagnostic loads validated module plan" {
  grep -F 'module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"' "$REPO_ROOT/diagnostic.sh"
  grep -F 'module_catalog_validate' "$REPO_ROOT/diagnostic.sh"
}

@test "diagnostic exposes architecture readiness only" {
  grep -F 'ARCHITECTURE PRE-TEST READY FOR MODULE CONTRACT REVIEW' "$REPO_ROOT/diagnostic.sh"
}

@test "menu has no installation or mutation option" {
  run grep -E '^[[:space:]]*[0-9]+\).*\b(install|apply|restore|backup|update|upgrade|delete|remove)\b' "$REPO_ROOT/menu.sh"
  [ "$status" -ne 0 ]
}

@test "installer remains hard disabled" {
  grep -F 'INSTALLER DISABLED' "$REPO_ROOT/install.sh"
  grep -F 'exit 10' "$REPO_ROOT/install.sh"
}
