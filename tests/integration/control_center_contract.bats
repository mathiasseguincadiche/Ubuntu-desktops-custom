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

@test "menu exposes dry-run but no real apply action" {
  grep -F 'Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP' "$REPO_ROOT/menu.sh"
  run grep -Ei '^[[:space:]]*[0-9]+\).*(appliquer|apply reel|apply réel|installation reelle|installation réelle|restaurer|sauvegarder|supprimer)' "$REPO_ROOT/menu.sh"
  [ "$status" -ne 0 ]
}

@test "installer writes current-commit dry-run proof" {
  grep -F 'apply_gate_write_dryrun_proof' "$REPO_ROOT/install.sh"
  grep -F 'verdict=FULL_DRY_RUN_PASS' "$REPO_ROOT/lib/apply_gate.sh"
}

@test "real apply feature remains hard closed" {
  grep -F 'REAL_APPLY_FEATURE_ENABLED=false' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL APPLY BLOCKED: feature flag REAL_APPLY_FEATURE_ENABLED=false.' "$REPO_ROOT/install.sh"
}

@test "future real apply requires backup proof and explicit confirmations" {
  grep -F 'REAL_APPLY_REQUIRE_VERIFIED_BACKUP=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_REQUIRE_EXACT_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_PHASE_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'apply_gate_verify_backup_proof' "$REPO_ROOT/lib/apply_gate.sh"
  grep -F 'apply_gate_confirm_phase' "$REPO_ROOT/install.sh"
}
