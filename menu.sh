#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$REPO_ROOT/lib/ui.sh"
ui_init

show_header() {
  ui_banner 'UBUNTU WORKSTATION CONTROL' 'POSTE UBUNTU 26.04 — DEVOPS / KVM / BACKUP'
  printf '\n'
  printf '%s\n' 'PRÉPARATION'
  printf '%s\n' '  1) Diagnostic global GO / NO-GO'
  printf '%s\n' '  2) Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP'
  printf '%s\n' '  3) Préparer et vérifier le backup pré-APPLY (Restic)'
  printf '\n'
  printf '%s\n' 'INSTALLATION'
  printf '%s\n' '  4) Installation reelle protegee (--apply)'
  printf '\n'
  printf '%s\n' 'OUTILS'
  printf '%s\n' '  5) Afficher le plan complet'
  printf '%s\n' '  6) Afficher les gates de securite'
  printf '%s\n' '  7) Lister les VM KVM'
  printf '%s\n' '  8) Lister les profils de VM optionnelles'
  printf '%s\n' '  9) Ouvrir le guide de demarrage (chemin)'
  printf '%s\n' ' 10) Remediation packaging applicatif pre-APPLY'
  printf '\n'
  printf '%s\n' '  0) Quitter'
  printf '\n'
  printf '%s\n' 'Parcours recommandé : 1 → 2 → 3 → 4'
}

show_plan() {
  # shellcheck source=lib/bootstrap.sh
  source "$REPO_ROOT/lib/bootstrap.sh"
  engine_bootstrap
  module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
  module_catalog_validate
  module_catalog_print_plan
}

show_kvm_profiles() {
  "$REPO_ROOT/scripts/kvm/vm-profile" list
}

show_security_gates() {
  # shellcheck source=lib/bootstrap.sh
  source "$REPO_ROOT/lib/bootstrap.sh"
  engine_bootstrap
  ui_banner 'GATES DE SÉCURITÉ' 'ÉTAT DE LA POLITIQUE D’EXÉCUTION'
  ui_check INFO 'REAL APPLY' "feature=${REAL_APPLY_FEATURE_ENABLED:-false} | approved=${REAL_MACHINE_APPROVED:-false}"
  ui_check INFO 'KVM fail-closed' "${KVM_FAIL_CLOSED:-false}"
  ui_check INFO 'Backup fail-closed' "${BACKUP_FAIL_CLOSED:-false}"
  ui_check INFO 'Cible externe' "${BACKUP_REQUIRE_EXTERNAL_TARGET:-false}"
  ui_info 'Les valeurs détaillées restent disponibles dans config/*.conf.'
}

while true; do
  show_header
  read -r -p 'Choix > ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/install.sh" --dry-run ;;
    3) bash "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    4)
      ui_warn 'L’APPLY réel reste protégé par le dry-run courant, le backup Restic vérifié et les confirmations interactives.'
      "$REPO_ROOT/install.sh" --apply
      ;;
    5) show_plan ;;
    6) show_security_gates ;;
    7) virsh -c qemu:///system list --all ;;
    8) show_kvm_profiles ;;
    9) printf '%s\n' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md" ;;
    10) bash "$REPO_ROOT/repair-packaging.sh" ;;
    0) exit 0 ;;
    *) ui_warn 'Choix invalide.' ;;
  esac
  printf '\n'
  read -r -p 'Entrée pour revenir au menu...' _
done
