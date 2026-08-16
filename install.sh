#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---dry-run}"

case "$MODE" in
  --dry-run|--apply) ;;
  *)
    printf 'Usage: %s [--dry-run|--apply]\n' "$0" >&2
    exit 2
    ;;
esac

# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

if [[ "$MODE" == '--apply' ]]; then
  if ! is_true "${REAL_APPLY_FEATURE_ENABLED:-false}"; then
    ui_blocked 'INSTALLATION RÉELLE BLOQUÉE' \
      'La fonctionnalité REAL APPLY est désactivée.' \
      'Aucune modification n’a été effectuée.' \
      'Vérifier le feature flag avant de relancer.' \
      "$MAIN_LOG"
    exit "$EXIT_SECURITY_BLOCK"
  fi
  if ! apply_gate_require_tty; then
    log_info ENGINE 'REAL APPLY BLOCKED: an interactive TTY is mandatory.'
    ui_error 'REAL APPLY BLOCKED: an interactive TTY is mandatory.'
    ui_blocked 'INSTALLATION RÉELLE BLOQUÉE' \
      'Un terminal interactif est obligatoire.' \
      'Aucune modification n’a été effectuée.' \
      'Relancer depuis un terminal interactif.' \
      "$MAIN_LOG"
    exit "$EXIT_SECURITY_BLOCK"
  fi
fi

module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate
for module_id in "${CATALOG_ORDER[@]}"; do
  module_adapter_register "$module_id"
done

if [[ "$MODE" == '--dry-run' ]]; then
  export DRY_RUN=true
  export REAL_MACHINE_APPROVED=false

  ui_banner 'UBUNTU WORKSTATION CONTROL' 'SIMULATION COMPLÈTE — DRY-RUN'
  ui_meta 'Mode' 'Simulation — aucune modification réelle'
  ui_meta 'Modules' "${#CATALOG_ORDER[@]}"
  ui_meta 'APPLY réel' 'BLOQUÉ pendant le dry-run'
  ui_meta 'Run ID' "$RUN_ID"
  ui_technical_paths

  if orchestrator_run_all; then
    report="$(orchestrator_report)"
    apply_gate_write_dryrun_proof
    ui_summary 'FULL DRY-RUN PASS' 'Préparer et vérifier le backup pré-APPLY (option 3)' "$report" "$LOG_DIR"
    exit 0
  else
    rc=$?
    printf 'VERDICT: FULL DRY-RUN FAIL (rc=%d)\n' "$rc" >> "$MAIN_LOG"
    report="$(orchestrator_report)"
    ui_summary "FULL DRY-RUN FAIL (rc=$rc)" 'Corriger l’étape en échec avant toute suite' "$report" "$LOG_DIR"
    exit "$rc"
  fi
fi

ui_banner 'UBUNTU WORKSTATION CONTROL' 'INSTALLATION RÉELLE PROTÉGÉE'
ui_meta 'Mode' 'APPLY réel — confirmations obligatoires'
ui_meta 'Run ID' "$RUN_ID"
ui_meta 'Sécurité' 'Fail-closed'
ui_technical_paths
ui_info 'Aucune mutation ne commence avant validation de tous les gates.'

# Hardware/OS preflight is read-only and must succeed on the actual workstation.
ACTIVE_SCOPE="$SCOPE_HOST"
if ! orchestrator_call "${ORCH_PRECHECK[host.preflight]}" >> "$MODULE_LOG" 2>&1; then
  ui_blocked 'APPLY BLOQUÉ' \
    'Le préflight du poste Ubuntu a échoué.' \
    'Aucune phase d’installation n’a démarré.' \
    'Consulter le log technique et corriger le préflight.' \
    "$MODULE_LOG"
  exit "$EXIT_PRECHECK_FAILED"
fi
ACTIVE_SCOPE=''
ui_check OK 'Préflight HOST' 'Machine compatible'

if ! apply_gate_open_runtime; then
  rc=$?
  ui_blocked 'APPLY BLOQUÉ PAR LE GATE FINAL' \
    "Un contrôle de sécurité a refusé l’exécution (rc=$rc)." \
    'L’installation réelle reste interdite.' \
    'Corriger le gate indiqué puis relancer depuis le menu.' \
    "$MAIN_LOG"
  exit "$rc"
fi
ui_check OK 'Gate final' 'Dry-run, backup, Git et confirmation validés'

# Every major domain requires an independent operator confirmation.
for scope in "$SCOPE_HOST" "$SCOPE_KVM" "$SCOPE_VM_DEVOPS" "$SCOPE_BACKUP"; do
  apply_gate_confirm_phase "$scope" || {
    rc=$?
    ui_blocked 'EXÉCUTION ARRÊTÉE' \
      "La phase $scope n’a pas été confirmée." \
      'Les phases suivantes n’ont pas été exécutées.' \
      'Relancer uniquement lorsque cette phase peut être approuvée.' \
      "$MAIN_LOG"
    exit "$rc"
  }
  orchestrator_run_scope "$scope" || exit "$?"

  if [[ "$scope" == "$SCOPE_HOST" ]] && is_true "${REAL_APPLY_VERIFY_APP_PACKAGING_AFTER_HOST:-true}"; then
    if app_packaging_require_posthost_converged; then
      log_info ENGINE 'HOST application packaging is fully converged: planned=0 drift=0 duplicates=0.'
      ui_check OK 'Packaging HOST' 'planned=0 | drift=0 | duplicates=0'
    else
      rc=$?
      ui_blocked 'APPLY ARRÊTÉ APRÈS HOST' \
        'La convergence du packaging applicatif a échoué.' \
        'KVM, VM_DEVOPS et BACKUP ne sont pas poursuivis.' \
        'Corriger le packaging avant de reprendre.' \
        "$MAIN_LOG"
      exit "$rc"
    fi
  fi
done

report="$(orchestrator_report)"
ui_summary 'REAL APPLY COMPLETED — POSTCHECKS REQUIRED' 'Contrôler les postchecks et le rapport final' "$report" "$LOG_DIR"
