#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

KEY_TMP="$(mktemp)"
KEYRING='/usr/share/keyrings/onlyoffice.gpg'
SOURCE='/etc/apt/sources.list.d/onlyoffice.list'
trap 'rm -f -- "$KEY_TMP"' EXIT

curl -fsSLo "$KEY_TMP" 'https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE'
gpg --batch --yes --dearmor --output "$KEYRING" "$KEY_TMP"
chmod 0644 "$KEYRING"
printf '%s\n' \
  "deb [arch=amd64 signed-by=$KEYRING] https://download.onlyoffice.com/repo/debian squeeze main" \
  > "$SOURCE"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install onlyoffice-desktopeditors
