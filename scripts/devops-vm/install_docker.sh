#!/usr/bin/env bash
set -Eeuo pipefail

operator="${1:?VM operator username required}"
[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }
id "$operator" >/dev/null 2>&1 || { printf 'ERROR: unknown user %s\n' "$operator" >&2; exit 2; }

apt-get update
apt-get -y install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
[[ -n "$codename" ]] || { printf '%s\n' 'ERROR: Ubuntu codename unavailable.' >&2; exit 3; }
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker "$operator"
systemctl enable --now docker
