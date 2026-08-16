#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "operator UI is centralized and supports technical opt-in" {
  ui="$REPO_ROOT/lib/ui.sh"
  grep -F 'ui_banner()' "$ui"
  grep -F 'ui_step_begin()' "$ui"
  grep -F 'ui_blocked()' "$ui"
  grep -F 'ui_summary()' "$ui"
  grep -F 'UW_UI_MODE' "$ui"
  grep -F 'NO_COLOR' "$ui"
}

@test "bootstrap loads UI before logging" {
  bootstrap="$REPO_ROOT/lib/bootstrap.sh"
  grep -F 'source "$REPO_ROOT/lib/ui.sh"' "$bootstrap"
  grep -F 'ui_init' "$bootstrap"
}

@test "technical logs are split by responsibility" {
  logging="$REPO_ROOT/lib/logging.sh"
  grep -F 'MAIN_LOG="$LOG_DIR/main.log"' "$logging"
  grep -F 'COMMAND_LOG="$LOG_DIR/commands.log"' "$logging"
  grep -F 'MODULE_LOG="$LOG_DIR/modules.log"' "$logging"
  grep -F 'log_command' "$REPO_ROOT/lib/runner.sh"
}

@test "operator orchestrator captures module technical output" {
  orchestrator="$REPO_ROOT/lib/orchestrator.sh"
  grep -F 'orchestrator_call_phase()' "$orchestrator"
  grep -F '>> "$MODULE_LOG" 2>&1' "$orchestrator"
  grep -F 'ui_step_begin' "$orchestrator"
  grep -F 'ui_step_ok' "$orchestrator"
  grep -F 'ui_step_fail' "$orchestrator"
}

@test "dry-run terminal uses operator summary instead of raw command lines" {
  installer="$REPO_ROOT/install.sh"
  grep -F "ui_banner 'UBUNTU WORKSTATION CONTROL' 'SIMULATION COMPLÈTE — DRY-RUN'" "$installer"
  grep -F "ui_summary 'FULL DRY-RUN PASS'" "$installer"
  run grep -F 'DRY-RUN would execute:' "$installer"
  [ "$status" -ne 0 ]
}

@test "menu keeps secure 1 2 3 4 path and groups tools" {
  menu="$REPO_ROOT/menu.sh"
  grep -F 'PRÉPARATION' "$menu"
  grep -F 'INSTALLATION' "$menu"
  grep -F 'OUTILS' "$menu"
  grep -F '1) Diagnostic global GO / NO-GO' "$menu"
  grep -F '2) Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP' "$menu"
  grep -F '3) Préparer et vérifier le backup pré-APPLY (Restic)' "$menu"
  grep -F '4) Installation reelle protegee (--apply)' "$menu"
  grep -F 'Parcours recommandé : 1 → 2 → 3 → 4' "$menu"
}

@test "pre-apply backup keeps Restic detail out of normal terminal" {
  script="$REPO_ROOT/prepare-preapply-backup.sh"
  grep -F 'RESTIC_UI_LOG="$LOG_DIR/restic.log"' "$script"
  grep -F '>> "$RESTIC_UI_LOG" 2>&1' "$script"
  grep -F "ui_summary 'PRE-APPLY BACKUP READY'" "$script"
  grep -F 'apply_gate_verify_dryrun_proof' "$script"
  grep -F 'apply_gate_verify_backup_proof' "$script"
}

@test "operator UI documentation defines terminal versus log contract" {
  doc="$REPO_ROOT/docs/OPERATOR_UI.md"
  grep -F '**terminal opérateur**' "$doc"
  grep -F '**logs techniques**' "$doc"
  grep -F 'UW_UI_MODE=technical' "$doc"
}
