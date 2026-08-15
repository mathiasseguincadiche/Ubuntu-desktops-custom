#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_header() {
  printf '%s\n' \
    'Ubuntu Workstation Control - PRE-TEST' \
    'Le dry-run complet est autorise; toute mutation reelle reste bloquee.' \
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

while true; do
  show_header
  cat <<'EOF'
1) Diagnostic global GO / NO-GO
2) Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP
3) Afficher le plan complet
4) Afficher les gates de securite
0) Quitter
EOF
  read -r -p 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/install.sh" --dry-run ;;
    3) show_plan ;;
    4)
      grep -E '^(REAL_MACHINE_APPROVED|KVM_FAIL_CLOSED|BACKUP_FAIL_CLOSED|BACKUP_REQUIRE_EXTERNAL_TARGET)=' \
        "$REPO_ROOT"/config/*.conf || true
      ;;
    0) exit 0 ;;
    *) printf '%s\n' 'Choix invalide.' ;;
  esac
  printf '\n'
  read -r -p 'Entree pour continuer...' _
done
