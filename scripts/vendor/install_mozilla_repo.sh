#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

for cmd in curl gpg apt-get apt-cache dpkg-query; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done

conflicts=()
if command -v snap >/dev/null 2>&1; then
  for app in firefox thunderbird; do
    if snap list "$app" >/dev/null 2>&1; then
      conflicts+=("$app:snap")
    fi
  done
fi
if command -v flatpak >/dev/null 2>&1; then
  for scope in system user; do
    for app_id in org.mozilla.firefox org.mozilla.Thunderbird; do
      if flatpak info --"$scope" "$app_id" >/dev/null 2>&1; then
        conflicts+=("$app_id:flatpak-$scope")
      fi
    done
  done
fi
if ((${#conflicts[@]} > 0)); then
  printf 'ERROR: packaging migration required before Mozilla APT install: %s\n' "${conflicts[*]}" >&2
  printf '%s\n' 'Run the read-only packaging inventory, migrate profiles if needed, then remove the conflicting package explicitly before APPLY.' >&2
  exit 1
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

Types: deb
URIs: https://packages.mozilla.org/apt
Suites: thunderbird-deb
Components: main
Signed-By: $KEYRING
EOF

cat > "$PREF" <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install firefox thunderbird

locale_name="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
locale_name="${locale_name%%:*}"
locale_name="${locale_name%%.*}"
language="${locale_name%%_*}"
if [[ -n "$language" && "$language" != C && "$language" != POSIX && "$language" != en ]]; then
  lang_packages=()
  for app in firefox thunderbird; do
    package="${app}-l10n-${language}"
    apt-cache show "$package" >/dev/null 2>&1 && lang_packages+=("$package")
  done
  if ((${#lang_packages[@]} > 0)); then
    DEBIAN_FRONTEND=noninteractive apt-get -y install "${lang_packages[@]}"
  fi
fi
