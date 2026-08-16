#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

repo_runtime="${BACKUP_REPOSITORY_RUNTIME:-}"
repo_restic="${RESTIC_REPOSITORY:-}"
password_file="${RESTIC_PASSWORD_FILE:-}"
proof="$REPO_ROOT/${REAL_APPLY_BACKUP_PROOF_FILE:-state/real-apply/backup-verified.pass}"
VERIFY_LOG="$LOG_DIR/restic-verify.log"
: > "$VERIFY_LOG"

verify_fail() {
  local message="$1" code="${2:-$EXIT_SECURITY_BLOCK}"
  log_info BACKUP "VERIFY BLOCKED: $message"
  ui_blocked 'VÉRIFICATION BACKUP BLOQUÉE' \
    "$message" \
    'La preuve BACKUP_VERIFIED n’est pas créée.' \
    'Corriger le contrôle indiqué puis relancer la préparation du backup.' \
    "$VERIFY_LOG" >&2
  exit "$code"
}

backup_local_source_is_external() {
  local source="$1" device name type tran removable hotplug
  device="$(readlink -f -- "$source" 2>/dev/null || true)"
  [[ -n "$device" && -b "$device" ]] || return 1

  while read -r name type tran removable hotplug; do
    [[ "$type" == disk ]] || continue
    if [[ "$tran" == usb || "$removable" == 1 || "$hotplug" == 1 ]]; then
      return 0
    fi
  done < <(lsblk -s -n -p -o NAME,TYPE,TRAN,RM,HOTPLUG "$device")

  return 1
}

if ! apply_gate_require_clean_worktree; then
  verify_fail 'Le worktree Git suivi doit être propre avant vérification.'
fi

if [[ -n "$repo_runtime" && -n "$repo_restic" && "$repo_runtime" != "$repo_restic" ]]; then
  # Contract token retained for tests/documentation: BACKUP_REPOSITORY_RUNTIME and RESTIC_REPOSITORY disagree.
  verify_fail 'BACKUP_REPOSITORY_RUNTIME and RESTIC_REPOSITORY disagree.' "$EXIT_INVALID_ARGUMENT"
fi
repo="${repo_runtime:-$repo_restic}"
[[ -n "$repo" ]] || verify_fail 'BACKUP_REPOSITORY_RUNTIME or RESTIC_REPOSITORY is required.' "$EXIT_INVALID_ARGUMENT"
[[ -n "$password_file" && -r "$password_file" ]] || verify_fail 'readable RESTIC_PASSWORD_FILE is required.' "$EXIT_INVALID_ARGUMENT"
for cmd in restic python3 findmnt lsblk readlink; do
  command -v "$cmd" >/dev/null 2>&1 || verify_fail "required command missing: $cmd" "$EXIT_PRECHECK_FAILED"
done

repo_path=''
case "$repo" in
  /*) repo_path="$repo" ;;
  local:*) repo_path="${repo#local:}" ;;
esac

if [[ -n "$repo_path" ]]; then
  [[ -e "$repo_path" ]] || verify_fail "local repository path does not exist: $repo_path" "$EXIT_PRECHECK_FAILED"
  root_source="$(findmnt -n -o SOURCE /)"
  repo_source="$(findmnt -n -o SOURCE -T "$repo_path")"
  [[ -n "$root_source" && -n "$repo_source" && "$root_source" != "$repo_source" ]] || \
    verify_fail 'local repository is on the protected root filesystem.'

  if is_true "${BACKUP_REQUIRE_EXTERNAL_TARGET:-true}" && ! backup_local_source_is_external "$repo_source"; then
    printf '%s\n' 'Use USB/removable/hotplug storage or a supported remote Restic backend; a second internal SSD is insufficient.' >> "$VERIFY_LOG"
    verify_fail "local repository is not proven external (source=$repo_source)."
  fi
fi

ui_banner 'VÉRIFICATION DU BACKUP' 'CONTRÔLE RESTIC EN LECTURE SEULE'
ui_meta 'Dépôt' "$repo"
ui_meta 'Log technique' "$VERIFY_LOG"
ui_check OK 'Worktree Git' 'Propre et lié au commit courant'
if [[ -n "$repo_path" ]]; then
  ui_check OK 'Cible externe' 'Filesystem distinct du système et stockage externe prouvé'
else
  ui_check OK 'Backend Restic' 'Backend distant — classification bloc locale non applicable'
fi

ui_info 'Vérification de la présence d’au moins un snapshot...'
restic --repo "$repo" --password-file "$password_file" --no-lock --json snapshots 2>> "$VERIFY_LOG" \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data else 1)' \
  || verify_fail 'Aucun snapshot Restic valide n’a été trouvé.' "$EXIT_PRECHECK_FAILED"
ui_check OK 'Snapshot' 'Au moins un snapshot est disponible'

ui_info 'Contrôle intégral des données Restic — cette étape peut prendre du temps...'
restic --repo "$repo" --password-file "$password_file" --no-lock check --read-data >> "$VERIFY_LOG" 2>&1 \
  || verify_fail 'restic check --read-data a échoué.' "$EXIT_POSTCHECK_FAILED"
ui_check OK 'Intégrité' 'restic check --read-data terminé avec succès'

commit="$(apply_gate_current_commit)"
[[ "$commit" != 'UNKNOWN' ]] || verify_fail 'current Git commit cannot be determined.'
apply_gate_require_clean_worktree || verify_fail 'tracked Git worktree changed during verification.'
ui_check OK 'Commit' "${commit:0:12} — worktree toujours propre"

safe_mkdir "$(dirname "$proof")"
{
  printf 'commit=%s\n' "$commit"
  printf 'created_epoch=%s\n' "$(date +%s)"
  printf 'repository=%s\n' "$repo"
  printf 'check=restic_check_read_data\n'
  printf 'worktree=clean_tracked\n'
  printf 'verdict=BACKUP_VERIFIED\n'
} > "$proof"
chmod 600 "$proof"

ui_summary 'BACKUP_VERIFIED' 'Le gate backup peut autoriser la suite du parcours' "$proof" "$VERIFY_LOG"
