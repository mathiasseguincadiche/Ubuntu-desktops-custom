#!/usr/bin/env bash

PRETEST_OK=0
PRETEST_WARN=0
PRETEST_KO=0
PRETEST_LINES=()

pretest_reset() {
  PRETEST_OK=0
  PRETEST_WARN=0
  PRETEST_KO=0
  PRETEST_LINES=()
}

pretest_record() {
  local status="$1" check="$2" detail="$3"
  case "$status" in
    OK) PRETEST_OK=$((PRETEST_OK + 1)) ;;
    WARN) PRETEST_WARN=$((PRETEST_WARN + 1)) ;;
    KO) PRETEST_KO=$((PRETEST_KO + 1)) ;;
    *) return "$EXIT_INVALID_ARGUMENT" ;;
  esac
  PRETEST_LINES+=("$status|$check|$detail")
}

pretest_check_catalog() {
  if module_catalog_load "$REPO_ROOT/manifests/module-plan.conf" && module_catalog_validate; then
    pretest_record OK 'MODULE CATALOG' "${#CATALOG_ORDER[@]} modules validated"
  else
    pretest_record KO 'MODULE CATALOG' 'invalid module manifest or dependency/path'
  fi
}

pretest_check_adapter_contracts() {
  local id failed=0
  for id in "${CATALOG_ORDER[@]}"; do
    if ! module_adapter_register "$id"; then
      pretest_record KO 'MODULE ADAPTER' "contract missing/invalid: $id"
      failed=1
      break
    fi
  done
  (( failed == 0 )) && pretest_record OK 'MODULE ADAPTER' 'all module contracts expose PRECHECK/PLAN/APPLY/POSTCHECK'
}

pretest_check_security() {
  [[ "${REAL_MACHINE_APPROVED:-false}" == 'false' ]] && \
    pretest_record OK 'REAL MACHINE GATE' 'closed' || pretest_record KO 'REAL MACHINE GATE' 'must remain closed during pre-test'
  [[ "${DRY_RUN:-true}" == 'true' ]] && \
    pretest_record OK 'DRY RUN' 'enabled' || pretest_record KO 'DRY RUN' 'must be enabled during architecture pre-test'
  [[ "${KVM_FAIL_CLOSED:-false}" == 'true' ]] && \
    pretest_record OK 'KVM FAIL-CLOSED' 'enabled' || pretest_record KO 'KVM FAIL-CLOSED' 'disabled or missing'
  [[ "${BACKUP_FAIL_CLOSED:-false}" == 'true' ]] && \
    pretest_record OK 'BACKUP FAIL-CLOSED' 'enabled' || pretest_record KO 'BACKUP FAIL-CLOSED' 'disabled or missing'
  [[ "${BACKUP_REQUIRE_EXTERNAL_TARGET:-false}" == 'true' ]] && \
    pretest_record OK 'BACKUP TARGET POLICY' 'external target required' || pretest_record KO 'BACKUP TARGET POLICY' 'external target not mandatory'
}

pretest_check_domains() {
  local domain id found
  for domain in HOST KVM VM_DEVOPS BACKUP; do
    found=0
    for id in "${CATALOG_ORDER[@]}"; do
      if [[ "${CATALOG_SCOPE[$id]}" == "$domain" ]]; then found=1; break; fi
    done
    (( found == 1 )) && pretest_record OK "$domain CONTRACT" 'module chain present' || pretest_record KO "$domain CONTRACT" 'module chain missing'
  done
}

pretest_check_installer_gate() {
  if grep -Fq 'INSTALLER DISABLED' "$REPO_ROOT/install.sh" && grep -Fq 'exit 10' "$REPO_ROOT/install.sh"; then
    pretest_record OK 'INSTALLER GATE' 'hard-disabled'
  else
    pretest_record KO 'INSTALLER GATE' 'installer is not demonstrably hard-disabled'
  fi
}

pretest_render() {
  local report="$REPORT_ROOT/$RUN_ID-pretest-audit.txt" line status check detail verdict
  (( PRETEST_KO == 0 )) && verdict='GO PRE-TEST' || verdict='NO-GO PRE-TEST'
  {
    printf '%s\n' '=== UBUNTU-DESKTOPS-CUSTOM GLOBAL PRE-TEST AUDIT ==='
    printf 'Run ID: %s\n\n' "$RUN_ID"
    for line in "${PRETEST_LINES[@]}"; do
      IFS='|' read -r status check detail <<< "$line"
      printf '%-4s | %-24s | %s\n' "$status" "$check" "$detail"
    done
    printf '\nSUMMARY: OK=%d | WARN=%d | KO=%d\n' "$PRETEST_OK" "$PRETEST_WARN" "$PRETEST_KO"
    printf 'REAL MACHINE APPLY: BLOCKED\n'
    printf 'VERDICT: %s\n' "$verdict"
  } | tee "$report"
  printf '\nReport: %s\n' "$report"
  (( PRETEST_KO == 0 ))
}

pretest_run() {
  pretest_reset
  orchestrator_reset
  pretest_check_catalog
  if (( PRETEST_KO == 0 )); then pretest_check_adapter_contracts; fi
  pretest_check_security
  pretest_check_domains
  pretest_check_installer_gate
  pretest_render
}
