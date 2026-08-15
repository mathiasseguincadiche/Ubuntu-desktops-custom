#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL='https://cloud-images.ubuntu.com/releases/26.04/release'
IMAGE_NAME='ubuntu-26.04-server-cloudimg-amd64.img'
KEYRING='/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg'
DEST="${1:?destination image path required}"

command -v curl >/dev/null 2>&1
command -v gpgv >/dev/null 2>&1
command -v sha256sum >/dev/null 2>&1
[[ -r "$KEYRING" ]] || { printf '%s\n' "ERROR: missing $KEYRING" >&2; exit 3; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSLo "$work/SHA256SUMS" "$BASE_URL/SHA256SUMS"
curl -fsSLo "$work/SHA256SUMS.gpg" "$BASE_URL/SHA256SUMS.gpg"
gpgv --keyring "$KEYRING" "$work/SHA256SUMS.gpg" "$work/SHA256SUMS"

grep -E "[[:space:]]\*?${IMAGE_NAME//./\.}$" "$work/SHA256SUMS" > "$work/image.sha256"
[[ -s "$work/image.sha256" ]] || { printf '%s\n' 'ERROR: image checksum missing from signed manifest.' >&2; exit 3; }

curl -fL --retry 3 --retry-delay 3 -o "$work/$IMAGE_NAME" "$BASE_URL/$IMAGE_NAME"
(
  cd "$work"
  sha256sum -c image.sha256
)
install -m 0644 "$work/$IMAGE_NAME" "$DEST"
