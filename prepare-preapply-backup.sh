#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

backup_fail() {
  local message="$1"
  local code="${2:-$EXIT_PRECHECK_FAILED}"
  printf 'BACKUP PREP BLOCKED: %s\n' "$message" >&2
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

backup_external_mount_candidates() {
  python3 - <<'PY'
import json
import subprocess

payload = subprocess.check_output([
    "lsblk", "-J", "-p", "-o",
    "NAME,TYPE,TRAN,RM,HOTPLUG,FSTYPE,MOUNTPOINTS",
], text=True)
data = json.loads(payload)

seen = set()

def walk(node, inherited_external=False):
    is_disk = node.get("type") == "disk"
    is_external = inherited_external or (
        is_disk
        and (
            node.get("tran") == "usb"
            or bool(node.get("rm"))
            or bool(node.get("hotplug"))
        )
    )
    if is_external:
        for mountpoint in node.get("mountpoints") or []:
            if mountpoint and mountpoint != "/" and mountpoint not in seen:
                seen.add(mountpoint)
                print(mountpoint)
    for child in node.get("children") or []:
        walk(child, is_external)

for device in data.get("blockdevices") or []:
    walk(device)
PY
}

backup_validate_mount() {
  local mountpoint="$1" source fstype options required_fstype
  [[ -d "$mountpoint" ]] || backup_fail "target mount does not exist: $mountpoint"

  source="$(findmnt -n -o SOURCE -T "$mountpoint" 2>/dev/null || true)"
  fstype="$(findmnt -n -o FSTYPE -T "$mountpoint" 2>/dev/null || true)"
  options="$(findmnt -n -o OPTIONS -T "$mountpoint" 2>/dev/null || true)"
  [[ -n "$source" && -n "$fstype" ]] || backup_fail "cannot resolve mounted filesystem for $mountpoint"
  [[ "$source" != "$(findmnt -n -o SOURCE /)" ]] || backup_fail 'target resolves to the protected root filesystem' "$EXIT_SECURITY_BLOCK"
  backup_local_source_is_external "$source" || backup_fail "target is not proven external (source=$source)" "$EXIT_SECURITY_BLOCK"

  required_fstype="${BACKUP_PREAPPLY_REQUIRED_FSTYPE:-ext4}"
  if [[ -n "$required_fstype" && "$fstype" != "$required_fstype" ]]; then
    backup_fail "target filesystem must be $required_fstype (found $fstype)"
  fi
  [[ ",$options," == *,rw,* ]] || backup_fail "target filesystem is not mounted read-write: $mountpoint"
}

backup_select_target_mount() {
  local override="${BACKUP_TARGET_MOUNT_RUNTIME:-}" candidate
  local -a candidates=()

  if [[ -n "$override" ]]; then
    candidate="$(readlink -f -- "$override" 2>/dev/null || true)"
    [[ -n "$candidate" ]] || backup_fail "cannot resolve BACKUP_TARGET_MOUNT_RUNTIME=$override"
    backup_validate_mount "$candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  mapfile -t candidates < <(backup_external_mount_candidates)
  if (( ${#candidates[@]} == 0 )); then
    backup_fail 'no mounted external USB/removable/hotplug filesystem found' "$EXIT_SECURITY_BLOCK"
  fi
  if (( ${#candidates[@]} > 1 )); then
    printf '%s\n' 'BACKUP PREP BLOCKED: multiple external targets detected:' >&2
    printf '  - %s\n' "${candidates[@]}" >&2
    printf '%s\n' 'Set BACKUP_TARGET_MOUNT_RUNTIME to the intended mounted filesystem and retry.' >&2
    exit "$EXIT_SECURITY_BLOCK"
  fi

  candidate="${candidates[0]}"
  backup_validate_mount "$candidate"
  printf '%s\n' "$candidate"
}

backup_validate_repository_subdir() {
  local subdir="$1"
  [[ -n "$subdir" && "$subdir" != /* ]] || backup_fail 'BACKUP_PREAPPLY_REPOSITORY_SUBDIR must be a non-empty relative path' "$EXIT_INVALID_ARGUMENT"
  case "/$subdir/" in
    */../*) backup_fail 'BACKUP_PREAPPLY_REPOSITORY_SUBDIR must not contain .. path segments' "$EXIT_INVALID_ARGUMENT" ;;
  esac
}

backup_ensure_repository_dir() {
  local target_mount="$1" repository="$2" parent uid gid
  parent="$(dirname "$repository")"
  uid="$(id -u)"
  gid="$(id -g)"

  if [[ ! -e "$parent" ]]; then
    if ! mkdir -p -m 0700 -- "$parent" 2>/dev/null; then
      command -v sudo >/dev/null 2>&1 || backup_fail "cannot create repository parent: $parent"
      sudo install -d -m 0700 -o "$uid" -g "$gid" -- "$parent"
    fi
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || backup_fail "repository parent is not a regular directory: $parent" "$EXIT_SECURITY_BLOCK"

  if [[ ! -e "$repository" ]]; then
    mkdir -m 0700 -- "$repository" || backup_fail "cannot create repository directory: $repository"
  fi
  [[ -d "$repository" && ! -L "$repository" ]] || backup_fail "repository path is not a regular directory: $repository" "$EXIT_SECURITY_BLOCK"

  local target_real repo_real repo_source target_source
  target_real="$(readlink -f -- "$target_mount")"
  repo_real="$(readlink -f -- "$repository")"
  case "$repo_real/" in
    "$target_real"/*) ;;
    *) backup_fail 'repository escaped the selected external target through path resolution' "$EXIT_SECURITY_BLOCK" ;;
  esac

  target_source="$(findmnt -n -o SOURCE -T "$target_mount")"
  repo_source="$(findmnt -n -o SOURCE -T "$repository")"
  [[ "$repo_source" == "$target_source" ]] || backup_fail 'repository is not located on the selected external filesystem' "$EXIT_SECURITY_BLOCK"
  [[ -w "$repository" ]] || backup_fail "repository directory is not writable by the current user: $repository"
}

backup_password_file() {
  local configured="${RESTIC_PASSWORD_FILE:-}"
  local relative="${BACKUP_PREAPPLY_PASSWORD_FILE_RELATIVE:-.config/ubuntu-desktops-custom/secrets/restic-password}"
  local password_file first second mode

  if [[ -n "$configured" ]]; then
    password_file="$configured"
  else
    password_file="$HOME/$relative"
  fi

  if [[ ! -s "$password_file" ]]; then
    [[ -t 0 && -t 1 ]] || backup_fail 'interactive TTY required to create the Restic password file' "$EXIT_SECURITY_BLOCK"
    mkdir -p -m 0700 -- "$(dirname "$password_file")"
    printf '%s\n' 'A Restic passphrase is required. It is never stored in Git.' >&2
    printf '%s\n' 'Keep this passphrase separately (for example in your password manager); the encrypted backup cannot be restored without it.' >&2
    read -r -s -p 'Restic passphrase (16+ characters): ' first
    printf '\n' >&2
    read -r -s -p 'Confirm Restic passphrase: ' second
    printf '\n' >&2
    [[ "$first" == "$second" ]] || backup_fail 'Restic passphrase confirmation does not match' "$EXIT_INVALID_ARGUMENT"
    (( ${#first} >= 16 )) || backup_fail 'Restic passphrase must contain at least 16 characters' "$EXIT_INVALID_ARGUMENT"
    printf '%s\n' "$first" > "$password_file"
    chmod 600 "$password_file"
    unset first second
  fi

  [[ -r "$password_file" ]] || backup_fail "Restic password file is not readable: $password_file"
  mode="$(stat -c '%a' "$password_file")"
  (( (8#$mode & 077) == 0 )) || backup_fail "Restic password file permissions are too broad ($mode): $password_file" "$EXIT_SECURITY_BLOCK"
  printf '%s\n' "$password_file"
}

backup_capture_inventory() {
  local inventory_dir="$1" commit="$2"
  mkdir -p -m 0700 -- "$inventory_dir"

  {
    printf 'commit=%s\n' "$commit"
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'created_at=%s\n' "$(uw_now)"
    printf 'hostname=%s\n' "$(hostname)"
  } > "$inventory_dir/metadata.txt"

  dpkg-query -W -f='${binary:Package}\t${Version}\n' > "$inventory_dir/dpkg-packages.tsv"
  apt-mark showmanual | sort > "$inventory_dir/apt-manual.txt"
  command -v snap >/dev/null 2>&1 && snap list > "$inventory_dir/snap-list.txt" || true
  command -v flatpak >/dev/null 2>&1 && flatpak list --app > "$inventory_dir/flatpak-apps.txt" || true
  systemctl list-unit-files --state=enabled --no-pager > "$inventory_dir/systemd-enabled.txt" || true
  lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS,TRAN,RM,HOTPLUG,MODEL > "$inventory_dir/lsblk.txt"
  findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS > "$inventory_dir/findmnt.txt"
  ip -4 route show > "$inventory_dir/ip-route.txt"
  lspci -nnk > "$inventory_dir/lspci-nnk.txt"
  printf 'ubuntu-desktops-custom pre-APPLY restore canary\ncommit=%s\nrun_id=%s\n' "$commit" "$RUN_ID" > "$inventory_dir/restore-canary.txt"
}

backup_build_sources() {
  local inventory_dir="$1" relative path
  local -a requested=(
    "/etc/fstab"
    "/etc/apt/sources.list"
    "/etc/apt/sources.list.d"
    "/etc/apt/keyrings"
    "/etc/apt/preferences.d"
    "/etc/systemd/system"
    "/etc/default"
    "/etc/modprobe.d"
    "/etc/sysctl.d"
    "/etc/udev/rules.d"
    "$HOME/.local/state/ubuntu-desktops-custom/migration-backups"
    "$REPO_ROOT/state/real-apply/full-dry-run.pass"
    "$inventory_dir"
  )

  BACKUP_SOURCES=()
  while IFS= read -r -d '' relative; do
    BACKUP_SOURCES+=("$REPO_ROOT/$relative")
  done < <(git -C "$REPO_ROOT" ls-files -z)

  for path in "${requested[@]}"; do
    [[ -e "$path" ]] || continue
    BACKUP_SOURCES+=("$path")
  done
  (( ${#BACKUP_SOURCES[@]} > 0 )) || backup_fail 'no backup source paths are available'
}

backup_require_free_space() {
  local mountpoint="$1" min_gib available min_bytes
  min_gib="${BACKUP_PREAPPLY_MIN_FREE_GIB:-20}"
  [[ "$min_gib" =~ ^[0-9]+$ ]] || backup_fail 'BACKUP_PREAPPLY_MIN_FREE_GIB must be an integer' "$EXIT_INVALID_ARGUMENT"
  available="$(df -PB1 --output=avail "$mountpoint" | awk 'NR==2 {print $1}')"
  [[ "$available" =~ ^[0-9]+$ ]] || backup_fail 'cannot determine free space on backup target'
  min_bytes=$((min_gib * 1024 * 1024 * 1024))
  (( available >= min_bytes )) || backup_fail "backup target has less than ${min_gib} GiB free"
  printf '%s\n' "$available"
}

for cmd in restic python3 findmnt lsblk readlink df stat git dpkg-query apt-mark systemctl ip lspci hostname; do
  command -v "$cmd" >/dev/null 2>&1 || backup_fail "required command missing: $cmd"
done

apply_gate_require_clean_worktree || backup_fail 'tracked Git worktree must be clean' "$EXIT_SECURITY_BLOCK"
apply_gate_verify_dryrun_proof || backup_fail 'a FULL_DRY_RUN_PASS proof for the current clean commit is required first' "$EXIT_SECURITY_BLOCK"

commit="$(apply_gate_current_commit)"
[[ "$commit" != UNKNOWN ]] || backup_fail 'current Git commit cannot be determined' "$EXIT_SECURITY_BLOCK"
short_commit="${commit:0:12}"
target_mount="$(backup_select_target_mount)"
repository_subdir="${BACKUP_PREAPPLY_REPOSITORY_SUBDIR:-Backup-Ubuntu/restic}"
backup_validate_repository_subdir "$repository_subdir"
repository="$target_mount/$repository_subdir"
available_bytes="$(backup_require_free_space "$target_mount")"

printf '%s\n' '=== PRE-APPLY BACKUP TARGET ==='
printf 'Commit:      %s\n' "$commit"
printf 'Mountpoint:  %s\n' "$target_mount"
printf 'Source:      %s\n' "$(findmnt -n -o SOURCE -T "$target_mount")"
printf 'Filesystem:  %s\n' "$(findmnt -n -o FSTYPE -T "$target_mount")"
printf 'Repository:  %s\n' "$repository"
printf 'Free bytes:  %s\n' "$available_bytes"
printf '%s\n' 'No formatting, partitioning or deletion of unrelated files will be performed.'

confirmation="${BACKUP_PREAPPLY_CONFIRMATION_PHRASE:-JE_CONFIRME_LA_CREATION_DU_BACKUP_PRE_APPLY}"
printf 'To create/update the encrypted pre-APPLY backup, type exactly: %s\n' "$confirmation"
read -r -p '> ' answer
[[ "$answer" == "$confirmation" ]] || backup_fail 'backup confirmation phrase rejected' "$EXIT_SECURITY_BLOCK"

backup_ensure_repository_dir "$target_mount" "$repository"
password_file="$(backup_password_file)"

if [[ -e "$repository/config" ]]; then
  restic --repo "$repository" --password-file "$password_file" --no-lock snapshots >/dev/null \
    || backup_fail 'existing Restic repository cannot be opened with the supplied password' "$EXIT_SECURITY_BLOCK"
elif [[ -n "$(find "$repository" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  backup_fail 'repository directory is non-empty but is not a Restic repository; refusing to overwrite it' "$EXIT_SECURITY_BLOCK"
else
  printf '%s\n' 'Initializing encrypted Restic repository...'
  restic --repo "$repository" --password-file "$password_file" init
fi

inventory_dir="$STATE_ROOT/preapply-backup/$RUN_ID"
backup_capture_inventory "$inventory_dir" "$commit"
backup_build_sources "$inventory_dir"

run_tag="run-$RUN_ID"
printf '%s\n' 'Creating pre-APPLY Restic snapshot...'
restic --repo "$repository" --password-file "$password_file" backup \
  --tag ubuntu-desktops-custom \
  --tag pre-apply \
  --tag "commit-$short_commit" \
  --tag "$run_tag" \
  "${BACKUP_SOURCES[@]}"

snapshot_id="$(
  restic --repo "$repository" --password-file "$password_file" --json snapshots --tag "$run_tag" \
    | python3 -c 'import json,sys; data=json.load(sys.stdin); ids=[x.get("id","") for x in data if x.get("id")]; raise SystemExit(1) if len(ids)!=1 else print(ids[0])'
)" || backup_fail 'cannot resolve the unique snapshot created by this run'

restore_dir="$inventory_dir/restore-test"
mkdir -p -m 0700 -- "$restore_dir"
canary="$inventory_dir/restore-canary.txt"
printf '%s\n' 'Running granular restore smoke test...'
restic --repo "$repository" --password-file "$password_file" restore "$snapshot_id" \
  --target "$restore_dir" --include "$canary"
restored_canary="$restore_dir$canary"
[[ -f "$restored_canary" ]] || backup_fail 'restore smoke test did not restore the canary file' "$EXIT_POSTCHECK_FAILED"
cmp -s "$canary" "$restored_canary" || backup_fail 'restored canary differs from source' "$EXIT_POSTCHECK_FAILED"

export BACKUP_REPOSITORY_RUNTIME="$repository"
export RESTIC_REPOSITORY="$repository"
export RESTIC_PASSWORD_FILE="$password_file"
"$REPO_ROOT/verify-preapply-backup.sh"

proof="$REPO_ROOT/${REAL_APPLY_BACKUP_PROOF_FILE:-state/real-apply/backup-verified.pass}"
apply_gate_verify_backup_proof || backup_fail 'backup verifier returned without a valid current backup proof' "$EXIT_SECURITY_BLOCK"

{
  printf 'commit=%s\n' "$commit"
  printf 'run_id=%s\n' "$RUN_ID"
  printf 'target_mount=%s\n' "$target_mount"
  printf 'repository=%s\n' "$repository"
  printf 'password_file=%s\n' "$password_file"
  printf 'snapshot_id=%s\n' "$snapshot_id"
  printf 'restore_test=PASS\n'
  printf 'verdict=PREAPPLY_BACKUP_READY\n'
} > "$STATE_ROOT/preapply-backup/latest.pass"
chmod 600 "$STATE_ROOT/preapply-backup/latest.pass"

printf '%s\n' 'PRE-APPLY BACKUP READY'
printf 'Repository: %s\n' "$repository"
printf 'Snapshot:   %s\n' "$snapshot_id"
printf 'Proof:      %s\n' "$proof"
printf '%s\n' 'NEXT STEP: return to menu and choose the protected real APPLY option.'
