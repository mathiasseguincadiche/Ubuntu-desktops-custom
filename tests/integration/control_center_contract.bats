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

@test "final pretest validates critical safety invariants" {
  grep -F 'pretest_check_kvm_network_contract' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_vm_host_separation' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_download_hygiene' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_mutation_boundaries' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_backup_safety' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "real machine apply remains explicitly blocked in report" {
  grep -F 'REAL MACHINE APPLY: BLOCKED' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "missing runtime credentials are warnings not fake readiness inputs" {
  grep -F "pretest_record WARN 'RUNTIME INPUTS'" "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "menu has no mutating action option" {
  run grep -Ei '^[[:space:]]*[0-9]+\).*(installer|appliquer|restaurer|sauvegarder|mettre a jour|mettre à jour|supprimer)' "$REPO_ROOT/menu.sh"
  [ "$status" -ne 0 ]
}

@test "installer remains hard disabled" {
  grep -F 'INSTALLER DISABLED' "$REPO_ROOT/install.sh"
  grep -F 'exit 10' "$REPO_ROOT/install.sh"
}
