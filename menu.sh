#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_header() {
  printf '%s\n' \
    'Ubuntu Workstation Control' \
    'Point d entree interactif pour diagnostic, dry-run, installation protegee et exploitation KVM.' \
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
3) Installation reelle protegee (--apply)
4) Afficher le plan complet
5) Afficher les gates de securite
6) Lister les VM KVM
7) Lister les profils de VM optionnelles
8) Ouvrir le guide de demarrage (chemin)
0) Quitter
EOF
  read -r -p 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/install.sh" --dry-run ;;
    3)
      printf '%s\n' \
        'L APPLY reel reste protege par le preflight, le dry-run du commit courant,' \
        'le backup Restic verifie et les confirmations interactives.'
      "$REPO_ROOT/install.sh" --apply
      ;;
    4) show_plan ;;
    5)
      grep -E '^(REAL_MACHINE_APPROVED|REAL_APPLY_FEATURE_ENABLED|KVM_FAIL_CLOSED|BACKUP_FAIL_CLOSED|BACKUP_REQUIRE_EXTERNAL_TARGET)=' \
        "$REPO_ROOT"/config/*.conf || true
      ;;
    6) virsh -c qemu:///system list --all ;;
    7) show_kvm_profiles ;;
    8) printf '%s\n' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md" ;;
    0) exit 0 ;;
    *) printf '%s\n' 'Choix invalide.' ;;
  esac
  printf '\n'
  read -r -p 'Entree pour continuer...' _
done
