#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }
command -v curl >/dev/null
command -v jq >/dev/null
command -v sha256sum >/dev/null

apt-get update
apt-get -y install shellcheck pipx tar

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Gitleaks: resolve latest official GitHub release and verify its published checksum.
gitleaks_tag="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r '.tag_name')"
[[ "$gitleaks_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Gitleaks release tag.' >&2; exit 2; }
gitleaks_version="${gitleaks_tag#v}"
gitleaks_archive="gitleaks_${gitleaks_version}_linux_x64.tar.gz"
curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${gitleaks_tag}/${gitleaks_archive}" -o "$tmp/$gitleaks_archive"
curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${gitleaks_tag}/gitleaks_${gitleaks_version}_checksums.txt" -o "$tmp/gitleaks-checksums.txt"
(
  cd "$tmp"
  grep -F "  $gitleaks_archive" gitleaks-checksums.txt | sha256sum --check --status
  tar -xzf "$gitleaks_archive" gitleaks
)
install -m 0755 "$tmp/gitleaks" /usr/local/bin/gitleaks

# Trivy: resolve latest release and verify the official checksums asset.
trivy_tag="$(curl -fsSL https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r '.tag_name')"
[[ "$trivy_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Trivy release tag.' >&2; exit 3; }
trivy_version="${trivy_tag#v}"
trivy_archive="trivy_${trivy_version}_Linux-64bit.tar.gz"
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${trivy_tag}/${trivy_archive}" -o "$tmp/$trivy_archive"
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${trivy_tag}/trivy_${trivy_version}_checksums.txt" -o "$tmp/trivy-checksums.txt"
(
  cd "$tmp"
  grep -F "  $trivy_archive" trivy-checksums.txt | sha256sum --check --status
  tar -xzf "$trivy_archive" trivy
)
install -m 0755 "$tmp/trivy" /usr/local/bin/trivy

# Hadolint: official release binary + official checksums.sha256.
hadolint_tag="$(curl -fsSL https://api.github.com/repos/hadolint/hadolint/releases/latest | jq -r '.tag_name')"
[[ "$hadolint_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid Hadolint release tag.' >&2; exit 4; }
hadolint_asset='hadolint-linux-x86_64'
curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${hadolint_tag}/${hadolint_asset}" -o "$tmp/$hadolint_asset"
curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${hadolint_tag}/checksums.sha256" -o "$tmp/hadolint-checksums.sha256"
(
  cd "$tmp"
  grep -F "  $hadolint_asset" hadolint-checksums.sha256 | sha256sum --check --status
)
install -m 0755 "$tmp/$hadolint_asset" /usr/local/bin/hadolint

# Checkov is isolated through pipx rather than polluting system Python.
pipx install --global checkov || pipx upgrade --global checkov

shellcheck --version
gitleaks version
trivy --version
hadolint --version
checkov --version
