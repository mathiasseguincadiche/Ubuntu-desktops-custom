#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }
command -v curl >/dev/null
command -v jq >/dev/null
command -v sha256sum >/dev/null

step() { printf '\n=== DEVSECOPS: %s ===\n' "$1"; }

verify_checksum_entry() {
  local checksum_file="$1" asset="$2" target="$3" digest
  digest="$(awk -v name="$asset" '$2 == name || $2 == "*" name {print $1; exit}' "$checksum_file")"
  [[ "$digest" =~ ^[0-9a-fA-F]{64}$ ]] || {
    printf 'ERROR: checksum entry missing/invalid for %s in %s\n' "$asset" "$checksum_file" >&2
    return 1
  }
  printf '%s  %s\n' "$digest" "$target" | sha256sum --check --status
}

step 'BASE PACKAGES'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install shellcheck pipx tar

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

step 'GITLEAKS'
gitleaks_tag="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r '.tag_name')"
[[ "$gitleaks_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Gitleaks release tag.' >&2; exit 2; }
gitleaks_version="${gitleaks_tag#v}"
gitleaks_archive="gitleaks_${gitleaks_version}_linux_x64.tar.gz"
curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${gitleaks_tag}/${gitleaks_archive}" -o "$tmp/$gitleaks_archive"
curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${gitleaks_tag}/gitleaks_${gitleaks_version}_checksums.txt" -o "$tmp/gitleaks-checksums.txt"
verify_checksum_entry "$tmp/gitleaks-checksums.txt" "$gitleaks_archive" "$tmp/$gitleaks_archive"
tar -xzf "$tmp/$gitleaks_archive" -C "$tmp" gitleaks
install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
gitleaks version

step 'TRIVY'
trivy_tag="$(curl -fsSL https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r '.tag_name')"
[[ "$trivy_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Trivy release tag.' >&2; exit 3; }
trivy_version="${trivy_tag#v}"
trivy_archive="trivy_${trivy_version}_Linux-64bit.tar.gz"
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${trivy_tag}/${trivy_archive}" -o "$tmp/$trivy_archive"
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${trivy_tag}/trivy_${trivy_version}_checksums.txt" -o "$tmp/trivy-checksums.txt"
verify_checksum_entry "$tmp/trivy-checksums.txt" "$trivy_archive" "$tmp/$trivy_archive"
tar -xzf "$tmp/$trivy_archive" -C "$tmp" trivy
install -m 0755 "$tmp/trivy" /usr/local/bin/trivy
trivy --version

step 'HADOLINT'
hadolint_tag="$(curl -fsSL https://api.github.com/repos/hadolint/hadolint/releases/latest | jq -r '.tag_name')"
[[ "$hadolint_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Hadolint release tag.' >&2; exit 4; }
hadolint_asset='hadolint-linux-x86_64'
curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${hadolint_tag}/${hadolint_asset}" -o "$tmp/$hadolint_asset"
curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${hadolint_tag}/checksums.sha256" -o "$tmp/hadolint-checksums.sha256"
verify_checksum_entry "$tmp/hadolint-checksums.sha256" "$hadolint_asset" "$tmp/$hadolint_asset"
install -m 0755 "$tmp/$hadolint_asset" /usr/local/bin/hadolint
hadolint --version

step 'CHECKOV'
if pipx list --global --short 2>/dev/null | grep -q '^checkov '; then
  pipx upgrade --global checkov
else
  pipx install --global checkov
fi
command -v checkov >/dev/null 2>&1 || {
  printf '%s\n' 'ERROR: checkov not found in PATH after pipx installation.' >&2
  exit 5
}
checkov --version

step 'SHELLCHECK'
shellcheck --version

printf '\n%s\n' 'DEVSECOPS STACK READY'
