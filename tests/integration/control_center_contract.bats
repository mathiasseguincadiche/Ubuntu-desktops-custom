#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "diagnostic delegates to the global read-only diagnostic" {
  grep -F 'engine_bootstrap' "$REPO_ROOT/diagnostic.sh"
  grep -F 'diagnostic_run' "$REPO_ROOT/diagnostic.sh"
}

@test "diagnostic audit validates catalog and module contracts" {
  grep -F 'module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'module_catalog_validate' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'module_adapter_register "$id"' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "diagnostic audit reports OK WARN KO and GO NO-GO" {
  grep -F 'SUMMARY: OK=%d | WARN=%d | KO=%d' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F "verdict='GO DIAGNOSTIC'" "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F "verdict='NO-GO DIAGNOSTIC'" "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "global diagnostic validates critical safety invariants and physical HOST" {
  grep -F 'pretest_check_kvm_network_contract' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_vm_host_separation' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_download_hygiene' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_mutation_boundaries' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_backup_safety' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'pretest_check_physical_host' "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "diagnostic keeps real machine apply gate closed by default" {
  grep -F 'REAL MACHINE APPLY GATE: CLOSED BY DEFAULT (EXPECTED)' "$REPO_ROOT/lib/pretest_audit.sh"
  grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
}

@test "missing runtime credentials are warnings not fake readiness inputs" {
  grep -F "pretest_record WARN 'RUNTIME INPUTS'" "$REPO_ROOT/lib/pretest_audit.sh"
}

@test "menu exposes dry-run and delegates real apply to guarded installer" {
  grep -F 'Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP' "$REPO_ROOT/menu.sh"
  grep -F 'Installation reelle protegee (--apply)' "$REPO_ROOT/menu.sh"
  grep -F '"$REPO_ROOT/install.sh" --apply' "$REPO_ROOT/menu.sh"
  run grep -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get|virsh|systemctl|nft)[[:space:]]+.*(install|upgrade|define|create|start|enable|delete|destroy|flush)' "$REPO_ROOT/menu.sh"
  [ "$status" -ne 0 ]
}

@test "installer writes current-commit dry-run proof" {
  grep -F 'apply_gate_write_dryrun_proof' "$REPO_ROOT/install.sh"
  grep -F 'verdict=FULL_DRY_RUN_PASS' "$REPO_ROOT/lib/apply_gate.sh"
}

@test "guarded apply path is enabled while static runtime approval stays closed" {
  grep -F 'REAL_APPLY_FEATURE_ENABLED=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'REAL APPLY BLOCKED: an interactive TTY is mandatory.' "$REPO_ROOT/install.sh"
  grep -F 'export REAL_MACHINE_APPROVED=true' "$REPO_ROOT/lib/apply_gate.sh"
}

@test "real apply requires backup proof and explicit confirmations" {
  grep -F 'REAL_APPLY_REQUIRE_CURRENT_COMMIT_DRY_RUN=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_REQUIRE_VERIFIED_BACKUP=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_REQUIRE_EXACT_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_PHASE_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'apply_gate_verify_backup_proof' "$REPO_ROOT/lib/apply_gate.sh"
  grep -F 'apply_gate_confirm_phase' "$REPO_ROOT/install.sh"
}
