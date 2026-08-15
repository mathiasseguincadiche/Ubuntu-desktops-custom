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

# Azure CLI: Ubuntu 26.04 Resolute must not silently reuse an unsupported repo.
. /etc/os-release
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
if [[ "$codename" == resolute && "${AZURE_CLI_ALLOW_NOBLE_FALLBACK:-false}" != true ]]; then
  printf '%s\n' 'AZURE_CLI_BLOCKED: Microsoft support for Ubuntu 26.04/Resolute has not been explicitly approved by project policy.' >&2
  exit 10
fi

if [[ "$codename" == resolute ]]; then
  repo_codename=noble
else
  repo_codename="$codename"
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$tmp/microsoft.asc"
gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg "$tmp/microsoft.asc"
chmod a+r /etc/apt/keyrings/microsoft.gpg
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ %s main\n' "$repo_codename" > /etc/apt/sources.list.d/azure-cli.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install azure-cli
az version
