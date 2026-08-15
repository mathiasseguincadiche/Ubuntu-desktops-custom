#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

KEY_ASC='/usr/share/keyrings/microsoft-vscode.asc'
KEY_GPG='/usr/share/keyrings/microsoft-vscode.gpg'
SOURCE='/etc/apt/sources.list.d/vscode.sources'

curl -fsSLo "$KEY_ASC" 'https://packages.microsoft.com/keys/microsoft.asc'
gpg --batch --yes --dearmor --output "$KEY_GPG" "$KEY_ASC"
printf '%s\n' \
  'Types: deb' \
  'URIs: https://packages.microsoft.com/repos/code' \
  'Suites: stable' \
  'Components: main' \
  'Architectures: amd64' \
  "Signed-By: $KEY_GPG" > "$SOURCE"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install code
