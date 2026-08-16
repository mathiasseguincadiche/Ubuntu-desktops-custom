#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

repo="${BACKUP_REPOSITORY_RUNTIME:-}"
password_file="${RESTIC_PASSWORD_FILE:-}"
proof="$REPO_ROOT/${REAL_APPLY_BACKUP_PROOF_FILE:-state/real-apply/backup-verified.pass}"

if ! apply_gate_require_clean_worktree; then
  printf '%s\n' 'BACKUP VERIFY BLOCKED: tracked Git worktree must be clean.' >&2
  exit "$EXIT_SECURITY_BLOCK"
fi

[[ -n "$repo" ]] || { printf '%s\n' 'BACKUP VERIFY BLOCKED: BACKUP_REPOSITORY_RUNTIME is required.' >&2; exit "$EXIT_INVALID_ARGUMENT"; }
[[ -n "$password_file" && -r "$password_file" ]] || { printf '%s\n' 'BACKUP VERIFY BLOCKED: readable RESTIC_PASSWORD_FILE is required.' >&2; exit "$EXIT_INVALID_ARGUMENT"; }
command -v restic >/dev/null 2>&1 || { printf '%s\n' 'BACKUP VERIFY BLOCKED: restic is not installed.' >&2; exit "$EXIT_PRECHECK_FAILED"; }
command -v python3 >/dev/null 2>&1 || { printf '%s\n' 'BACKUP VERIFY BLOCKED: python3 is required.' >&2; exit "$EXIT_PRECHECK_FAILED"; }

# A local repository must live on a different mounted filesystem from root.
repo_path=''
case "$repo" in
  /*) repo_path="$repo" ;;
  local:*) repo_path="${repo#local:}" ;;
esac

if [[ -n "$repo_path" ]]; then
  [[ -e "$repo_path" ]] || { printf 'BACKUP VERIFY BLOCKED: local repository path does not exist: %s\n' "$repo_path" >&2; exit "$EXIT_PRECHECK_FAILED"; }
  root_source="$(findmnt -n -o SOURCE /)"
  repo_source="$(findmnt -n -o SOURCE -T "$repo_path")"
  [[ -n "$root_source" && -n "$repo_source" && "$root_source" != "$repo_source" ]] || {
    printf '%s\n' 'BACKUP VERIFY BLOCKED: local repository is on the protected root filesystem.' >&2
    exit "$EXIT_SECURITY_BLOCK"
  }
fi

printf '%s\n' 'Checking that at least one Restic snapshot exists...'
restic --repo "$repo" --password-file "$password_file" --no-lock --json snapshots \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data else 1)'

printf '%s\n' 'Running full Restic repository/data integrity check (read-only)...'
restic --repo "$repo" --password-file "$password_file" --no-lock check --read-data

commit="$(apply_gate_current_commit)"
[[ "$commit" != 'UNKNOWN' ]] || { printf '%s\n' 'BACKUP VERIFY BLOCKED: current Git commit cannot be determined.' >&2; exit "$EXIT_SECURITY_BLOCK"; }
apply_gate_require_clean_worktree || { printf '%s\n' 'BACKUP VERIFY BLOCKED: tracked Git worktree changed during verification.' >&2; exit "$EXIT_SECURITY_BLOCK"; }

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
printf 'BACKUP VERIFIED. Proof: %s\n' "$proof"
