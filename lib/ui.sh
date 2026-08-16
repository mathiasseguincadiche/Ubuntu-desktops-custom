#!/usr/bin/env bash

UI_MODE_CURRENT='operator'
UI_USE_COLOR=false
UI_STEP_INDEX=0
UI_STEP_TOTAL=0
UI_STEP_ID=''
UI_STEP_LABEL=''
UI_SCOPE_CURRENT=''

ui_init() {
  UI_MODE_CURRENT="${UW_UI_MODE:-${UI_DEFAULT_MODE:-operator}}"
  case "$UI_MODE_CURRENT" in
    operator|technical) ;;
    *) UI_MODE_CURRENT='operator' ;;
  esac

  UI_USE_COLOR=false
  if [[ "$UI_MODE_CURRENT" == operator && -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    UI_USE_COLOR=true
  fi
}

ui_is_operator() {
  [[ "${UI_MODE_CURRENT:-operator}" == operator ]]
}

ui_color() {
  local code="$1"
  if [[ "${UI_USE_COLOR:-false}" == true ]]; then
    printf '\033[%sm' "$code"
  fi
}

ui_reset_color() {
  if [[ "${UI_USE_COLOR:-false}" == true ]]; then
    printf '\033[0m'
  fi
}

ui_status_text() {
  local status="$1"
  case "$status" in
    OK|READY|PASS) printf '%s' 'OK' ;;
    RUNNING) printf '%s' 'EN COURS' ;;
    INFO) printf '%s' 'INFO' ;;
    WARN) printf '%s' 'ATTENTION' ;;
    BLOCKED) printf '%s' 'BLOQUÉ' ;;
    FAIL|ERROR) printf '%s' 'ÉCHEC' ;;
    SKIP) printf '%s' 'IGNORÉ' ;;
    *) printf '%s' "$status" ;;
  esac
}

ui_status_color() {
  local status="$1"
  case "$status" in
    OK|READY|PASS) ui_color '1;32' ;;
    RUNNING|INFO) ui_color '1;36' ;;
    WARN) ui_color '1;33' ;;
    BLOCKED|FAIL|ERROR) ui_color '1;31' ;;
    SKIP) ui_color '2;37' ;;
    *) ui_color '0' ;;
  esac
}

ui_rule() {
  printf '%s\n' '──────────────────────────────────────────────────────────────────────'
}

ui_banner() {
  local title="$1" subtitle="${2:-}"
  printf '\n'
  printf '%s\n' '╔══════════════════════════════════════════════════════════════════════╗'
  printf '║ %-68s ║\n' "$title"
  if [[ -n "$subtitle" ]]; then
    printf '║ %-68s ║\n' "$subtitle"
  fi
  printf '%s\n' '╚══════════════════════════════════════════════════════════════════════╝'
}

ui_meta() {
  local label="$1" value="$2"
  printf '  %-14s : %s\n' "$label" "$value"
}

ui_scope_title() {
  case "$1" in
    HOST) printf '%s' 'STATION UBUNTU' ;;
    KVM) printf '%s' 'VIRTUALISATION KVM' ;;
    VM_DEVOPS) printf '%s' 'VM DEVOPS' ;;
    BACKUP) printf '%s' 'SAUVEGARDE' ;;
    *) printf '%s' "$1" ;;
  esac
}

ui_scope_description() {
  case "$1" in
    HOST) printf '%s' 'Système, matériel, applications et poste de travail' ;;
    KVM) printf '%s' 'QEMU/libvirt, stockage et réseau isolé' ;;
    VM_DEVOPS) printf '%s' 'Ubuntu Server 26.04 et outillage DevOps' ;;
    BACKUP) printf '%s' 'Protection Restic, intégrité et restauration' ;;
    *) printf '%s' '' ;;
  esac
}

ui_section() {
  local scope="$1"
  UI_SCOPE_CURRENT="$scope"
  printf '\n'
  printf '[ %s ]  %s\n' "$(ui_scope_title "$scope")" "$(ui_scope_description "$scope")"
  ui_rule
}

ui_module_label() {
  case "$1" in
    host.preflight) printf '%s' 'Compatibilité de la machine' ;;
    host.os_updates) printf '%s' 'Mises à jour Ubuntu' ;;
    host.firmware_microcode) printf '%s' 'Microcode AMD et firmware' ;;
    host.graphics) printf '%s' 'Intel Arc B580 et pile graphique' ;;
    host.multimedia) printf '%s' 'Multimédia et codecs' ;;
    host.apps) printf '%s' 'Applications desktop' ;;
    host.terminal) printf '%s' 'Terminal, Bash et SSH' ;;
    host.gaming) printf '%s' 'Gaming et runtimes 32 bits' ;;
    host.observability) printf '%s' 'Observabilité matérielle' ;;
    host.validation) printf '%s' 'Validation du poste Ubuntu' ;;
    kvm.preflight) printf '%s' 'Préflight KVM' ;;
    kvm.stack) printf '%s' 'QEMU et libvirt' ;;
    kvm.firmware) printf '%s' 'UEFI et TPM virtuel' ;;
    kvm.storage) printf '%s' 'Stockage des machines virtuelles' ;;
    kvm.network) printf '%s' 'Réseau NAT isolé devops-nat' ;;
    kvm.catalog) printf '%s' 'Catalogue des images Ubuntu' ;;
    kvm.cli) printf '%s' 'Administration CLI KVM' ;;
    kvm.ssh) printf '%s' 'Accès SSH HOST vers VM' ;;
    kvm.validation) printf '%s' 'Validation KVM' ;;
    vm.preflight) printf '%s' 'Préflight de la VM DevOps' ;;
    vm.identity_ssh) printf '%s' 'Identité réseau et SSH' ;;
    vm.cloud_init) printf '%s' 'Image Ubuntu et cloud-init' ;;
    vm.provision) printf '%s' 'Provisionnement ubuntu-devops' ;;
    vm.base) printf '%s' 'Outils système de base' ;;
    vm.git) printf '%s' 'Git et OpenSSH' ;;
    vm.cloud_clis) printf '%s' 'CLI AWS et Azure' ;;
    vm.iac) printf '%s' 'Terraform et Ansible' ;;
    vm.docker) printf '%s' 'Docker Engine' ;;
    vm.kubernetes) printf '%s' 'Kubernetes, Helm et kind' ;;
    vm.devsecops) printf '%s' 'Outils DevSecOps' ;;
    vm.validation) printf '%s' 'Validation de la VM DevOps' ;;
    backup.preflight) printf '%s' 'Préflight de sauvegarde' ;;
    backup.inventory) printf '%s' 'Inventaire à protéger' ;;
    backup.repository) printf '%s' 'Dépôt Restic chiffré' ;;
    backup.host) printf '%s' 'Protection de la station Ubuntu' ;;
    backup.kvm) printf '%s' 'Protection de la configuration KVM' ;;
    backup.vm) printf '%s' 'Protection des machines virtuelles' ;;
    backup.integrity) printf '%s' 'Intégrité et rétention' ;;
    backup.restore) printf '%s' 'Restauration granulaire' ;;
    backup.dr) printf '%s' 'Reprise après sinistre' ;;
    backup.validation) printf '%s' 'Validation du contrat de sauvegarde' ;;
    *) printf '%s' "$1" ;;
  esac
}

ui_module_detail() {
  case "$1" in
    host.preflight) printf '%s' 'Ubuntu 26.04, AMD-V, KVM et stockage compatibles' ;;
    host.apps) printf '%s' 'Packaging contrôlé sans suppression implicite' ;;
    kvm.storage) printf '%s' 'Cible prévue : /data/libvirt/images' ;;
    kvm.network) printf '%s' 'Internet autorisé, réseau physique isolé' ;;
    vm.identity_ssh) printf '%s' 'Adresse déterministe sur devops-nat' ;;
    vm.provision) printf '%s' '8 vCPU | 16 Gio RAM | 200 Gio qcow2' ;;
    vm.docker) printf '%s' 'Installé uniquement dans VM_DEVOPS' ;;
    backup.repository) printf '%s' 'Cible externe et chiffrement obligatoires' ;;
    backup.restore) printf '%s' 'Test de restauration obligatoire avant GO' ;;
    *) printf '%s' '' ;;
  esac
}

ui_step_format() {
  local index="$1" total="$2" label="$3" status="$4"
  local prefix status_text dots_count dots=''
  prefix="[$(printf '%02d' "$index")/$(printf '%02d' "$total")] $label"
  status_text="$(ui_status_text "$status")"
  dots_count=$((58 - ${#prefix} - ${#status_text}))
  (( dots_count < 3 )) && dots_count=3
  printf -v dots '%*s' "$dots_count" ''
  dots="${dots// /.}"
  printf '  %s %s ' "$prefix" "$dots"
  ui_status_color "$status"
  printf '%s' "$status_text"
  ui_reset_color
}

ui_step_begin() {
  UI_STEP_INDEX="$1"
  UI_STEP_TOTAL="$2"
  UI_STEP_ID="$3"
  UI_STEP_LABEL="$(ui_module_label "$UI_STEP_ID")"
  if [[ -t 1 ]]; then
    ui_step_format "$UI_STEP_INDEX" "$UI_STEP_TOTAL" "$UI_STEP_LABEL" RUNNING
    printf '\r'
  else
    ui_step_format "$UI_STEP_INDEX" "$UI_STEP_TOTAL" "$UI_STEP_LABEL" RUNNING
    printf '\n'
  fi
}

ui_step_end() {
  local status="$1" detail="${2:-}"
  if [[ -t 1 ]]; then
    printf '\r\033[2K'
  fi
  ui_step_format "$UI_STEP_INDEX" "$UI_STEP_TOTAL" "$UI_STEP_LABEL" "$status"
  printf '\n'
  if [[ -n "$detail" ]]; then
    printf '          %s\n' "$detail"
  fi
}

ui_step_ok() {
  local detail="${1:-}"
  [[ -n "$detail" ]] || detail="$(ui_module_detail "$UI_STEP_ID")"
  ui_step_end OK "$detail"
}

ui_step_skip() {
  ui_step_end SKIP "${1:-Étape déjà validée}"
}

ui_step_fail() {
  ui_step_end FAIL "${1:-Échec de l'étape}"
}

ui_info() {
  printf '  '
  ui_status_color INFO
  printf 'INFO'
  ui_reset_color
  printf '  %s\n' "$*"
}

ui_warn() {
  printf '  '
  ui_status_color WARN
  printf 'ATTENTION'
  ui_reset_color
  printf '  %s\n' "$*" >&2
}

ui_error() {
  printf '  '
  ui_status_color ERROR
  printf 'ÉCHEC'
  ui_reset_color
  printf '  %s\n' "$*" >&2
}

ui_check() {
  local status="$1" label="$2" detail="$3"
  printf '  %-11s | %-26s | %s\n' "$(ui_status_text "$status")" "$label" "$detail"
}

ui_blocked() {
  local title="$1" problem="$2" consequence="$3" action="$4" log_path="${5:-}"
  printf '\n'
  printf '┌─ %s ─────────────────────────────────────────────────────\n' "$title"
  printf '│ Problème     : %s\n' "$problem"
  printf '│ Conséquence  : %s\n' "$consequence"
  printf '│ Action       : %s\n' "$action"
  if [[ -n "$log_path" ]]; then
    printf '│ Log technique: %s\n' "$log_path"
  fi
  printf '%s\n' '└─────────────────────────────────────────────────────────────────────'
}

ui_summary() {
  local verdict="$1" next_step="$2" report="$3" log_path="${4:-}"
  printf '\n'
  printf '%s\n' '╔══════════════════════════ RÉSULTAT ═════════════════════════════════╗'
  printf '║ %-68s ║\n' "VERDICT     : $verdict"
  printf '║ %-68s ║\n' "PROCHAINE   : $next_step"
  printf '%s\n' '╚══════════════════════════════════════════════════════════════════════╝'
  [[ -n "$report" ]] && ui_meta 'Rapport' "$report"
  [[ -n "$log_path" ]] && ui_meta 'Log complet' "$log_path"
}

ui_technical_paths() {
  [[ -n "${MAIN_LOG:-}" ]] && ui_meta 'Log moteur' "$MAIN_LOG"
  [[ -n "${COMMAND_LOG:-}" ]] && ui_meta 'Log commandes' "$COMMAND_LOG"
  [[ -n "${MODULE_LOG:-}" ]] && ui_meta 'Log modules' "$MODULE_LOG"
}
