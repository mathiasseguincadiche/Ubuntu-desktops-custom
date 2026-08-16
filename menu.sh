#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_header() {
  printf '%s\n' \
    'Ubuntu Workstation Control' \
    'Point d entree interactif pour diagnostic, dry-run, backup pré-APPLY, installation protegee et exploitation KVM.' \
    ''
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

while true; do
  show_header
  cat <<'EOF'
1) Diagnostic global GO / NO-GO
2) Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP
3) Préparer et vérifier le backup pré-APPLY (Restic)
4) Installation reelle protegee (--apply)
5) Afficher le plan complet
6) Afficher les gates de securite
7) Lister les VM KVM
8) Lister les profils de VM optionnelles
9) Ouvrir le guide de demarrage (chemin)
10) Remediation packaging applicatif pre-APPLY
0) Quitter
EOF
  read -r -p 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/install.sh" --dry-run ;;
    3) bash "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    4)
      printf '%s\n' \
        'L APPLY reel reste protege par le preflight, le dry-run du commit courant,' \
        'le backup Restic verifie et les confirmations interactives.'
      "$REPO_ROOT/install.sh" --apply
      ;;
    5) show_plan ;;
    6)
      grep -E '^(REAL_MACHINE_APPROVED|REAL_APPLY_FEATURE_ENABLED|KVM_FAIL_CLOSED|BACKUP_FAIL_CLOSED|BACKUP_REQUIRE_EXTERNAL_TARGET)=' \
        "$REPO_ROOT"/config/*.conf || true
      ;;
    7) virsh -c qemu:///system list --all ;;
    8) show_kvm_profiles ;;
    9) printf '%s\n' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md" ;;
    10) bash "$REPO_ROOT/repair-packaging.sh" ;;
    0) exit 0 ;;
    *) printf '%s\n' 'Choix invalide.' ;;
  esac
  printf '\n'
  read -r -p 'Entree pour continuer...' _
done
