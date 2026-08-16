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
    pretest_record OK 'REAL MACHINE GATE' 'closed by default as required' || pretest_record KO 'REAL MACHINE GATE' 'must remain closed outside the final APPLY gate'
  [[ "${DRY_RUN:-true}" == 'true' ]] && \
    pretest_record OK 'DRY RUN' 'enabled during diagnostic' || pretest_record KO 'DRY RUN' 'diagnostic must remain non-mutating'
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
  local installer="$REPO_ROOT/install.sh"
  local gate_cfg="$REPO_ROOT/config/apply-gate.conf"
  local gate_lib="$REPO_ROOT/lib/apply_gate.sh"
  local failed=0 token

  for token in \
    'apply_gate_require_tty' \
    'apply_gate_open_runtime' \
    'apply_gate_confirm_phase'; do
    grep -Fq "$token" "$installer" || failed=1
  done

  for token in \
    'REAL_APPLY_REQUIRE_TTY=true' \
    'REAL_APPLY_REQUIRE_CURRENT_COMMIT_DRY_RUN=true' \
    'REAL_APPLY_REQUIRE_VERIFIED_BACKUP=true' \
    'REAL_APPLY_REQUIRE_EXACT_CONFIRMATION=true' \
    'REAL_APPLY_PHASE_CONFIRMATION=true'; do
    grep -Fqx "$token" "$gate_cfg" || failed=1
  done

  grep -Fq 'export REAL_MACHINE_APPROVED=true' "$gate_lib" || failed=1
  grep -Fq 'apply_gate_check || return "$?"' "$gate_lib" || failed=1

  (( failed == 0 )) && pretest_record OK 'INSTALLER GATE' 'guarded --apply path enforced' || \
    pretest_record KO 'INSTALLER GATE' 'required APPLY gates are missing or bypassable'
}

pretest_check_kvm_network_contract() {
  local cfg="$REPO_ROOT/config/virtualization.conf" failed=0 token
  for token in \
    'KVM_NETWORK_CIDR=192.168.50.0/24' \
    'KVM_GATEWAY=192.168.50.254' \
    'KVM_DHCP_START=192.168.50.100' \
    'KVM_DHCP_END=192.168.50.200' \
    'KVM_DNS_1=9.9.9.9' \
    'KVM_DNS_2=1.1.1.1' \
    'KVM_BLOCK_PHYSICAL_LAN=true' \
    'KVM_ALLOW_VM_INTERNET=true' \
    'KVM_ALLOW_INBOUND_FORWARDING=false'; do
    grep -Fqx "$token" "$cfg" || failed=1
  done
  (( failed == 0 )) && pretest_record OK 'KVM NETWORK CONTRACT' 'frozen NAT/DHCP/DNS/isolation policy intact' || \
    pretest_record KO 'KVM NETWORK CONTRACT' 'frozen network policy drift detected'
}

pretest_check_vm_host_separation() {
  if grep -Fq 'devops_tooling_on_host: forbidden' "$REPO_ROOT/manifests/devops-vm/tools.yml" && \
     grep -R -Eq 'vm_remote_(run|copy)_mutating' "$REPO_ROOT/modules/devops-vm"; then
    pretest_record OK 'HOST / VM SEPARATION' 'DevOps tooling is VM-scoped and remotely transported'
  else
    pretest_record KO 'HOST / VM SEPARATION' 'DevOps tooling ownership/transport contract invalid'
  fi
}

pretest_check_download_hygiene() {
  if grep -R -n -E '^[[:space:]]*(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)([[:space:]]|$)' \
      "$REPO_ROOT/scripts" --include='*.sh' >/dev/null 2>&1; then
    pretest_record KO 'DOWNLOAD HYGIENE' 'executable curl/wget pipe-to-shell detected'
  else
    pretest_record OK 'DOWNLOAD HYGIENE' 'no executable curl/wget pipe-to-shell path'
  fi

  if grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?apt-key([[:space:]]|$)' \
      "$REPO_ROOT/scripts" "$REPO_ROOT/modules" --include='*.sh' >/dev/null 2>&1; then
    pretest_record KO 'APT KEY HYGIENE' 'deprecated apt-key execution detected'
  else
    pretest_record OK 'APT KEY HYGIENE' 'signed keyring/source model enforced'
  fi
}

pretest_check_mutation_boundaries() {
  local pattern offender
  pattern='^[[:space:]]*(sudo[[:space:]]+)?((apt|apt-get)[[:space:]].*(install|remove|purge|upgrade|full-upgrade|dist-upgrade|autoremove)([[:space:]]|$)|dnf[[:space:]].*(install|remove|upgrade|update)([[:space:]]|$)|snap[[:space:]].*(install|remove|refresh)([[:space:]]|$)|flatpak[[:space:]].*(install|uninstall|update)([[:space:]]|$)|systemctl[[:space:]].*(enable|disable|start|stop|restart|reload|daemon-reload|mask|unmask)([[:space:]]|$)|virsh[[:space:]].*(define|undefine|destroy|start|shutdown|reboot|reset|net-define|net-undefine|net-start|net-destroy|net-autostart|pool-define|pool-define-as|pool-start|pool-destroy|pool-autostart|vol-create|vol-create-as|vol-delete|attach-device|detach-device|update-device)([[:space:]]|$)|qemu-img[[:space:]].*(create|resize|convert|rebase|commit|snapshot)([[:space:]]|$)|virt-install([[:space:]]|$)|nft[[:space:]].*(add|delete|flush|insert|replace|create|destroy)([[:space:]]|$)|iptables[[:space:]].*-[ADFIRNXP]([[:space:]]|$))'

  offender="$(grep -R -n -E "$pattern" "$REPO_ROOT/modules" --include='*.sh' 2>/dev/null | head -n 1 || true)"
  if [[ -n "$offender" ]]; then
    pretest_record KO 'MUTATION BOUNDARIES' "raw mutating command found: $offender"
  else
    pretest_record OK 'MUTATION BOUNDARIES' 'mutations are mediated; read-only probes are allowed'
  fi
}

pretest_check_backup_safety() {
  local cfg="$REPO_ROOT/config/backup.conf"
  if grep -Fqx 'BACKUP_ENCRYPTION_REQUIRED=true' "$cfg" && \
     grep -Fqx 'BACKUP_INTEGRITY_CHECK_REQUIRED=true' "$cfg" && \
     grep -Fqx 'BACKUP_RESTORE_TEST_REQUIRED=true' "$cfg" && \
     grep -Fqx 'BACKUP_ALLOW_LIVE_QCOW2_COPY=false' "$cfg"; then
    pretest_record OK 'BACKUP SAFETY' 'encryption, integrity, restore test and qcow2 consistency enforced'
  else
    pretest_record KO 'BACKUP SAFETY' 'backup safety invariant missing'
  fi
}

pretest_check_runtime_inputs() {
  local warnings=0
  [[ -n "${VM_ADMIN_SSH_PRIVATE_KEY_FILE:-}" ]] || warnings=$((warnings + 1))
  [[ -n "${BACKUP_REPOSITORY:-}" ]] || warnings=$((warnings + 1))
  if (( warnings > 0 )); then
    pretest_record WARN 'RUNTIME INPUTS' 'real-run credentials/targets not supplied yet'
  else
    pretest_record OK 'RUNTIME INPUTS' 'runtime inputs supplied'
  fi
}

pretest_check_physical_host() {
  local previous_scope="${ACTIVE_SCOPE:-}" rc=0
  if [[ -z "${ORCH_PRECHECK[host.preflight]:-}" ]]; then
    pretest_record KO 'PHYSICAL HOST PREFLIGHT' 'host.preflight adapter is unavailable'
    return 0
  fi

  ACTIVE_SCOPE="$SCOPE_HOST"
  if orchestrator_call "${ORCH_PRECHECK[host.preflight]}"; then
    pretest_record OK 'PHYSICAL HOST PREFLIGHT' 'Ubuntu/SVM/EXT4/KVM compatibility checks passed'
  else
    rc=$?
    pretest_record KO 'PHYSICAL HOST PREFLIGHT' "read-only HOST preflight failed (rc=$rc)"
  fi
  ACTIVE_SCOPE="$previous_scope"
}

pretest_render() {
  local report="$REPORT_ROOT/$RUN_ID-diagnostic-audit.txt" line status check detail verdict next_step
  if (( PRETEST_KO == 0 )); then
    verdict='GO DIAGNOSTIC'
    next_step='FULL DRY-RUN'
  else
    verdict='NO-GO DIAGNOSTIC'
    next_step='CORRECT KO BEFORE DRY-RUN'
  fi
  {
    printf '%s\n' '=== UBUNTU-DESKTOPS-CUSTOM GLOBAL READ-ONLY DIAGNOSTIC ==='
    printf 'Run ID: %s\n\n' "$RUN_ID"
    for line in "${PRETEST_LINES[@]}"; do
      IFS='|' read -r status check detail <<< "$line"
      printf '%-4s | %-24s | %s\n' "$status" "$check" "$detail"
    done
    printf '\nSUMMARY: OK=%d | WARN=%d | KO=%d\n' "$PRETEST_OK" "$PRETEST_WARN" "$PRETEST_KO"
    printf '%s\n' 'REAL MACHINE APPLY GATE: CLOSED BY DEFAULT (EXPECTED)'
    printf 'NEXT STEP: %s\n' "$next_step"
    printf 'VERDICT: %s\n' "$verdict"
  } | tee "$report"
  printf '\nReport: %s\n' "$report"
  (( PRETEST_KO == 0 ))
}

diagnostic_run() {
  pretest_reset
  orchestrator_reset
  pretest_check_catalog
  if (( PRETEST_KO == 0 )); then pretest_check_adapter_contracts; fi
  pretest_check_security
  pretest_check_domains
  pretest_check_installer_gate
  pretest_check_kvm_network_contract
  pretest_check_vm_host_separation
  pretest_check_download_hygiene
  pretest_check_mutation_boundaries
  pretest_check_backup_safety
  pretest_check_runtime_inputs
  pretest_check_physical_host
  pretest_render
}

# Backward-compatible internal alias for existing callers/tests.
pretest_run() {
  diagnostic_run
}
