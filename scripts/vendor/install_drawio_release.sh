#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1
command -v jq >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1

API='https://api.github.com/repos/jgraph/drawio-desktop/releases/latest'
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
META="$TMP_DIR/release.json"
DEB="$TMP_DIR/drawio.deb"

curl -fsSLo "$META" "$API"
asset_name="$(jq -r '[.assets[] | select(.name | test("^drawio-amd64-[0-9].*\\.deb$|^draw.io-amd64-[0-9].*\\.deb$|^drawio-x86_64-[0-9].*\\.deb$"))][0].name // empty' "$META")"
if [[ -z "$asset_name" ]]; then
  asset_name="$(jq -r '[.assets[] | select(.name | test("\\.deb$")) | select(.name | test("arm64|aarch64") | not)][0].name // empty' "$META")"
fi
[[ -n "$asset_name" ]] || { printf '%s\n' 'ERROR: no amd64 Linux DEB asset found.' >&2; exit 1; }

url="$(jq -r --arg n "$asset_name" '.assets[] | select(.name == $n) | .browser_download_url' "$META")"
digest="$(jq -r --arg n "$asset_name" '.assets[] | select(.name == $n) | .digest // empty' "$META")"
[[ "$digest" == sha256:* ]] || { printf '%s\n' 'ERROR: GitHub release asset has no SHA-256 digest.' >&2; exit 1; }
expected="${digest#sha256:}"

curl -fL --retry 3 --retry-delay 2 -o "$DEB" "$url"
printf '%s  %s\n' "$expected" "$DEB" | sha256sum -c -
DEBIAN_FRONTEND=noninteractive apt-get -y install "$DEB"
