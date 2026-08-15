#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }

apt-get update
apt-get -y install ca-certificates curl gnupg lsb-release ansible-core ansible-lint
install -m 0755 -d /etc/apt/keyrings

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL https://apt.releases.hashicorp.com/gpg -o "$tmp"
gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg "$tmp"
chmod a+r /etc/apt/keyrings/hashicorp-archive-keyring.gpg

codename="$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
[[ -n "$codename" ]] || { printf '%s\n' 'ERROR: Ubuntu codename unavailable.' >&2; exit 2; }
printf 'deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com %s main\n' "$codename" > /etc/apt/sources.list.d/hashicorp.list

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install terraform
terraform version
ansible --version
ansible-lint --version
