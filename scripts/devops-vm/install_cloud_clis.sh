#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }

apt-get update
apt-get -y install ca-certificates curl unzip gnupg

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# AWS CLI v2 official installer. Download to disk first: never curl|sh.
curl -fsSL https://awscli.amazonaws.com/v2/install.sh -o "$tmp/aws-install.sh"
chmod 0755 "$tmp/aws-install.sh"
"$tmp/aws-install.sh" --system
aws --version

# Microsoft documents using an earlier Ubuntu repository when the current
# distribution does not yet have an Azure CLI package. Project policy pins
# that compatibility fallback explicitly instead of silently guessing.
. /etc/os-release
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
[[ -n "$codename" ]] || { printf '%s\n' 'ERROR: Ubuntu codename unavailable.' >&2; exit 2; }
repo_codename="$codename"
if [[ "$codename" == resolute ]]; then
  repo_codename="${AZURE_CLI_REPO_FALLBACK:-jammy}"
  [[ "$repo_codename" == jammy ]] || { printf '%s\n' 'ERROR: Azure CLI fallback must remain jammy for Resolute unless policy is revised.' >&2; exit 3; }
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$tmp/microsoft.asc"
gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg "$tmp/microsoft.asc"
chmod a+r /etc/apt/keyrings/microsoft.gpg
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ %s main\n' "$repo_codename" > /etc/apt/sources.list.d/azure-cli.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install azure-cli
az version
