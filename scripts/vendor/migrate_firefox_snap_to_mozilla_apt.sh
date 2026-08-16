#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
desktop_user="${DESKTOP_USER:-${SUDO_USER:-}}"
[[ -n "$desktop_user" && "$desktop_user" != root ]] || {
  printf '%s\n' 'ERROR: a non-root desktop user is required.' >&2
  exit 1
}

for cmd in getent id snap tar sha256sum apt-get apt-cache dpkg-query sudo find pgrep awk; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done
[[ -r "$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh" ]] || {
  printf '%s\n' 'ERROR: Mozilla installer is missing.' >&2
  exit 1
}

stream_contains_exact() {
  local needle="$1"
  awk -v needle="$needle" '$0 == needle { found=1 } END { exit(found ? 0 : 1) }'
}

stream_contains_fixed() {
  local needle="$1"
  awk -v needle="$needle" 'index($0, needle) { found=1 } END { exit(found ? 0 : 1) }'
}

desktop_home="$(getent passwd "$desktop_user" | awk -F: '{print $6}')"
desktop_group="$(id -gn "$desktop_user")"
[[ -n "$desktop_home" && -d "$desktop_home" ]] || {
  printf '%s\n' 'ERROR: desktop home could not be resolved.' >&2
  exit 1
}

snap_profile_root="$desktop_home/snap/firefox/common/.mozilla/firefox"
native_profile_root="$desktop_home/.mozilla/firefox"
backup_root="$desktop_home/.local/state/ubuntu-desktops-custom/migration-backups/firefox"
timestamp="$(date +%Y%m%dT%H%M%S%z)"
archive="$backup_root/firefox-snap-profile-$timestamp.tar.gz"
checksum="$archive.sha256"
stage='preflight'
backup_verified=false

on_error() {
  local rc=$?
  printf 'ERROR: Firefox migration failed during stage=%s (rc=%d).\n' "$stage" "$rc" >&2
  if [[ "$backup_verified" == true ]]; then
    printf 'Verified migration backup retained at: %s\n' "$archive" >&2
  elif [[ -n "${archive:-}" && -s "${archive:-}" ]]; then
    printf 'Migration backup file retained but verification did not complete: %s\n' "$archive" >&2
  fi
  exit "$rc"
}
trap on_error ERR

snap list firefox >/dev/null 2>&1 || {
  printf '%s\n' 'ERROR: Firefox Snap is not installed; migration does not apply.' >&2
  exit 1
}

if command -v flatpak >/dev/null 2>&1; then
  if flatpak info --system org.mozilla.firefox >/dev/null 2>&1 || \
     sudo -u "$desktop_user" flatpak info --user org.mozilla.firefox >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: Firefox Flatpak also exists; three-way migration is intentionally unsupported.' >&2
    exit 1
  fi
fi

uid="$(id -u "$desktop_user")"
if pgrep -u "$uid" -x firefox >/dev/null 2>&1 || pgrep -u "$uid" -x firefox-bin >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: Firefox is running. Quit Firefox completely before migration.' >&2
  exit 1
fi

[[ -r "$snap_profile_root/profiles.ini" ]] || {
  printf 'ERROR: expected Snap profile metadata is missing: %s\n' "$snap_profile_root/profiles.ini" >&2
  exit 1
}

if [[ -d "$native_profile_root" ]] && [[ -n "$(find "$native_profile_root" -mindepth 1 -print -quit)" ]]; then
  printf 'ERROR: native Firefox profile already contains data: %s\n' "$native_profile_root" >&2
  printf '%s\n' 'Automatic profile merging is intentionally refused.' >&2
  exit 1
fi

stage='profile-backup'
install -d -m 0700 -o "$desktop_user" -g "$desktop_group" "$backup_root"
sudo -u "$desktop_user" tar -C "$desktop_home/snap/firefox/common/.mozilla" -czf "$archive" firefox
sha256sum "$archive" > "$checksum"
chown "$desktop_user:$desktop_group" "$checksum"
sha256sum -c "$checksum"
backup_verified=true
tar -tzf "$archive" | stream_contains_exact 'firefox/profiles.ini'

# Stage the official Mozilla repository while the Snap still exists. This does not
# install a second Firefox; it only prepares and validates the future APT candidate.
stage='mozilla-repository-preflight'
bash "$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh" --configure-only
apt-cache policy firefox | stream_contains_fixed 'packages.mozilla.org'
apt-get --simulate --allow-downgrades install firefox >/dev/null

stage='snap-removal'
snap remove firefox

stage='mozilla-apt-install'
bash "$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh"

[[ "$(dpkg-query -W -f='${Status}\n' firefox)" == 'install ok installed' ]]
apt-cache policy firefox | stream_contains_fixed 'packages.mozilla.org'
! snap list firefox >/dev/null 2>&1

stage='profile-restore'
install -d -m 0700 -o "$desktop_user" -g "$desktop_group" "$desktop_home/.mozilla"
if [[ -d "$native_profile_root" ]]; then
  rmdir -- "$native_profile_root"
fi
sudo -u "$desktop_user" tar -C "$desktop_home/.mozilla" -xzf "$archive"
[[ -r "$native_profile_root/profiles.ini" ]]
[[ -n "$(find "$native_profile_root" -mindepth 2 -name places.sqlite -print -quit)" ]]

stage='final-validation'
sha256sum -c "$checksum"
! snap list firefox >/dev/null 2>&1
apt-cache policy firefox | stream_contains_fixed 'packages.mozilla.org'

trap - ERR
printf '%s\n' 'Firefox migration completed successfully.'
printf 'Mozilla APT profile restored to: %s\n' "$native_profile_root"
printf 'Verified backup retained at: %s\n' "$archive"
printf '%s\n' 'Do not delete the backup until Firefox has been opened and bookmarks/passwords/extensions have been verified.'
