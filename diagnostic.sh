#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"

engine_bootstrap

ui_banner 'UBUNTU WORKSTATION CONTROL' 'DIAGNOSTIC GLOBAL — LECTURE SEULE'
ui_meta 'Mode' 'Diagnostic — aucune modification'
ui_meta 'Run ID' "$RUN_ID"
ui_technical_paths

diagnostic_rc=0
diagnostic_raw="$LOG_DIR/diagnostic.raw.log"
if diagnostic_run > "$diagnostic_raw" 2>&1; then
  :
else
  diagnostic_rc=$?
fi
cat "$diagnostic_raw" >> "$MAIN_LOG"

printf '\n[ CONTRÔLES ]  Sécurité, architecture et compatibilité\n'
ui_rule
for line in "${PRETEST_LINES[@]}"; do
  IFS='|' read -r status check detail <<< "$line"
  ui_check "$status" "$check" "$detail"
done

printf '\n'
ui_meta 'OK' "$PRETEST_OK"
ui_meta 'Attention' "$PRETEST_WARN"
ui_meta 'Échec' "$PRETEST_KO"
ui_info 'REAL MACHINE APPLY GATE: CLOSED BY DEFAULT (EXPECTED)'

packaging_raw="$LOG_DIR/packaging.raw.log"
if app_packaging_inventory_run > "$packaging_raw" 2>&1; then
  cat "$packaging_raw" >> "$MAIN_LOG"
  printf '\n[ PACKAGING ]  État des applications desktop\n'
  ui_rule
  ui_check INFO 'APPLICATION PACKAGING INVENTORY' "tracked=$APP_PACKAGING_TRACKED"
  ui_check OK 'Applications suivies' "$APP_PACKAGING_TRACKED"
  ui_check OK 'Déjà conformes' "$APP_PACKAGING_CONFORMING"
  if (( APP_PACKAGING_PLANNED > 0 )); then
    ui_check INFO 'À installer' "$APP_PACKAGING_PLANNED prévues pendant l’APPLY"
  else
    ui_check OK 'À installer' '0 — environnement convergé'
  fi

  if (( APP_PACKAGING_DUPLICATES > 0 || APP_PACKAGING_DRIFT > 0 )); then
    ui_check WARN 'Cohérence packaging' "drift=$APP_PACKAGING_DRIFT | duplicates=$APP_PACKAGING_DUPLICATES"
    if (( ${#APP_PACKAGING_ISSUES[@]} > 0 )); then
      ui_warn "Points à revoir : $(IFS=';'; printf '%s' "${APP_PACKAGING_ISSUES[*]}")"
    fi
  else
    ui_check OK 'Cohérence packaging' 'drift=0 | duplicates=0'
  fi
  ui_info 'READ-ONLY: no package, snap or flatpak was installed, removed, refreshed or migrated.'
  printf '  Packaging report: %s\n' "$APP_PACKAGING_REPORT"
else
  cat "$packaging_raw" >> "$MAIN_LOG" 2>/dev/null || true
  ui_check KO 'Packaging applicatif' 'Impossible d’évaluer la politique ou l’inventaire'
  (( diagnostic_rc != 0 )) || diagnostic_rc="$EXIT_PRECHECK_FAILED"
fi

report="$REPORT_ROOT/$RUN_ID-diagnostic-audit.txt"
if (( diagnostic_rc == 0 && PRETEST_KO == 0 )); then
  ui_summary 'GO DIAGNOSTIC' 'FULL DRY-RUN' "$report" "$LOG_DIR"
else
  ui_summary 'NO-GO DIAGNOSTIC' 'CORRECT KO BEFORE DRY-RUN' "$report" "$LOG_DIR"
fi

exit "$diagnostic_rc"
