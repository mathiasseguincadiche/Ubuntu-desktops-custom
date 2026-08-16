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
  printf '%s\n' 'BACKUP VERIFY BLOCKED: tracked Git worktree must be clean.' >&2
  exit "$EXIT_SECURITY_BLOCK"
fi

if [[ -n "$repo_runtime" && -n "$repo_restic" && "$repo_runtime" != "$repo_restic" ]]; then
  printf '%s\n' 'BACKUP VERIFY BLOCKED: BACKUP_REPOSITORY_RUNTIME and RESTIC_REPOSITORY disagree.' >&2
  exit "$EXIT_INVALID_ARGUMENT"
fi
repo="${repo_runtime:-$repo_restic}"
[[ -n "$repo" ]] || {
  printf '%s\n' 'BACKUP VERIFY BLOCKED: BACKUP_REPOSITORY_RUNTIME or RESTIC_REPOSITORY is required.' >&2
  exit "$EXIT_INVALID_ARGUMENT"
}
[[ -n "$password_file" && -r "$password_file" ]] || { printf '%s\n' 'BACKUP VERIFY BLOCKED: readable RESTIC_PASSWORD_FILE is required.' >&2; exit "$EXIT_INVALID_ARGUMENT"; }
for cmd in restic python3 findmnt lsblk readlink; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'BACKUP VERIFY BLOCKED: required command missing: %s\n' "$cmd" >&2; exit "$EXIT_PRECHECK_FAILED"; }
done

# A local repository must be on a different filesystem and, when external-target
# policy is enabled, on storage that the kernel exposes as USB/removable/hotplug.
# Remote Restic backends are not local block devices and therefore bypass only
# this local-device classification, not the snapshot/integrity/commit gates.
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

  if is_true "${BACKUP_REQUIRE_EXTERNAL_TARGET:-true}" && ! backup_local_source_is_external "$repo_source"; then
    printf 'BACKUP VERIFY BLOCKED: local repository is not proven external (source=%s).\n' "$repo_source" >&2
    printf '%s\n' 'Use USB/removable/hotplug storage or a supported remote Restic backend; a second internal SSD is insufficient.' >&2
    exit "$EXIT_SECURITY_BLOCK"
  fi
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
