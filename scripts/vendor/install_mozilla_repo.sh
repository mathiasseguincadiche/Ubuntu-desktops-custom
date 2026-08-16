#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

mode='install'
case "${1:-}" in
  '') ;;
  --configure-only) mode='configure-only' ;;
  *)
    printf 'Usage: %s [--configure-only]\n' "$0" >&2
    exit 2
    ;;
esac

for cmd in curl gpg apt-get apt-cache dpkg-query; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done

if [[ "$mode" == install ]]; then
  conflicts=()
  if command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
    conflicts+=("firefox:snap")
  fi
  if command -v flatpak >/dev/null 2>&1; then
    for scope in system user; do
      if flatpak info --"$scope" org.mozilla.firefox >/dev/null 2>&1; then
        conflicts+=("org.mozilla.firefox:flatpak-$scope")
      fi
    done
  fi
  if ((${#conflicts[@]} > 0)); then
    printf 'ERROR: packaging migration required before Mozilla APT install: %s\n' "${conflicts[*]}" >&2
    printf '%s\n' 'Run the read-only packaging inventory or the dedicated packaging remediation before APPLY.' >&2
    exit 1
  fi
fi

KEY_TMP="$(mktemp)"
KEYRING='/etc/apt/keyrings/packages.mozilla.org.asc'
SOURCE='/etc/apt/sources.list.d/mozilla.sources'
PREF='/etc/apt/preferences.d/mozilla'
EXPECTED_FPR='35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3'
trap 'rm -f -- "$KEY_TMP"' EXIT

install -d -m 0755 /etc/apt/keyrings
curl -fsSLo "$KEY_TMP" 'https://packages.mozilla.org/apt/repo-signing-key.gpg'
actual_fpr="$(gpg --batch --show-keys --with-colons "$KEY_TMP" | awk -F: '$1=="fpr" {print $10; exit}')"
[[ "$actual_fpr" == "$EXPECTED_FPR" ]] || {
  printf 'ERROR: Mozilla signing-key fingerprint mismatch: %s\n' "${actual_fpr:-missing}" >&2
  exit 1
}
install -m 0644 "$KEY_TMP" "$KEYRING"

cat > "$SOURCE" <<EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: $KEYRING
EOF

cat > "$PREF" <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

apt-get update
if [[ "$mode" == configure-only ]]; then
  printf '%s\n' 'Mozilla APT repository configured and refreshed; Firefox package not installed.'
  exit 0
fi

# Ubuntu's firefox package can be a higher-epoch Snap transition package.
# The Mozilla origin is fingerprint-verified and pinned at 1000, so this explicit
# downgrade permission is limited to replacing that transition package with the
# selected Mozilla candidate.
DEBIAN_FRONTEND=noninteractive apt-get -y --allow-downgrades install firefox

locale_name="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
locale_name="${locale_name%%:*}"
locale_name="${locale_name%%.*}"
language="${locale_name%%_*}"
if [[ -n "$language" && "$language" != C && "$language" != POSIX && "$language" != en ]]; then
  package="firefox-l10n-${language}"
  if apt-cache show "$package" >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get -y install "$package"
  fi
fi
