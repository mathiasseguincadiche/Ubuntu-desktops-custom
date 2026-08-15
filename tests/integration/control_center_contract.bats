#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "diagnostic delegates to global pretest audit" {
  grep -F 'engine_bootstrap' "$REPO_ROOT/diagnostic.sh"
  grep -F 'pretest_run' "$REPO_ROOT/diagnostic.sh"
}

@test "pretest audit validates catalog and module contracts" {
  grep -F 'module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'module_catalog_validate' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'module_adapter_register "$id"' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "pretest audit reports OK WARN KO and GO NO-GO" {
  grep -F 'SUMMARY: OK=%d | WARN=%d | KO=%d' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F "verdict='GO PRE-TEST'" "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F "verdict='NO-GO PRE-TEST'" "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "real machine apply remains explicitly blocked in report" {
  grep -F 'REAL MACHINE APPLY: BLOCKED' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "menu has no installation or mutation option" {
  run grep -Ei '^[[:space:]]*[0-9]+\).*(install|apply|restore|backup|update|upgrade|delete|remove)' "$REPO_ROOT/menu.sh"
  [ "$status" -ne 0 ]
}

@test "installer remains hard disabled" {
  grep -F 'INSTALLER DISABLED' "$REPO_ROOT/install.sh"
  grep -F 'exit 10' "$REPO_ROOT/install.sh"
}
