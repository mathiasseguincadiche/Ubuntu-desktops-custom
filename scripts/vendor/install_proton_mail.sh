#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
for cmd in curl jq sha512sum apt-get dpkg-deb; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done

METADATA_URL='https://proton.me/download/mail/linux/version.json'
TMPDIR_PROTON="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR_PROTON"' EXIT
METADATA="$TMPDIR_PROTON/version.json"
DEB="$TMPDIR_PROTON/ProtonMail-desktop-beta.deb"

curl -fsSLo "$METADATA" "$METADATA_URL"

release_json="$(jq -c '[.Releases[] | select(.CategoryName == "Stable")][0]' "$METADATA")"
[[ "$release_json" != null && -n "$release_json" ]] || {
  printf '%s\n' 'ERROR: Proton metadata has no Stable Linux release.' >&2
  exit 1
}

version="$(jq -r '.Version' <<<"$release_json")"
deb_url="$(jq -r '.File[] | select(.Identifier | test("\\.deb")) | .Url' <<<"$release_json" | head -n1)"
expected_sha512="$(jq -r '.File[] | select(.Identifier | test("\\.deb")) | .Sha512CheckSum' <<<"$release_json" | head -n1)"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: invalid Proton version: %s\n' "$version" >&2; exit 1; }
[[ "$deb_url" == "https://proton.me/download/mail/linux/$version/ProtonMail-desktop-beta.deb" ]] || {
  printf 'ERROR: unexpected Proton DEB URL: %s\n' "$deb_url" >&2
  exit 1
}
[[ "$expected_sha512" =~ ^[0-9a-fA-F]{128}$ ]] || { printf '%s\n' 'ERROR: invalid Proton SHA-512 metadata.' >&2; exit 1; }

curl -fsSLo "$DEB" "$deb_url"
printf '%s  %s\n' "$expected_sha512" "$DEB" | sha512sum --check --status || {
  printf '%s\n' 'ERROR: Proton Mail SHA-512 verification failed.' >&2
  exit 1
}

package_name="$(dpkg-deb -f "$DEB" Package)"
[[ "$package_name" == proton-mail ]] || {
  printf 'ERROR: unexpected Proton Mail Debian package name: %s\n' "$package_name" >&2
  exit 1
}

DEBIAN_FRONTEND=noninteractive apt-get -y install "$DEB"
printf 'Proton Mail %s installed from verified official DEB.\n' "$version"
