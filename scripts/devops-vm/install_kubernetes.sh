#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }
command -v curl >/dev/null
command -v sha256sum >/dev/null
command -v jq >/dev/null

arch="$(dpkg --print-architecture)"
[[ "$arch" == amd64 ]] || { printf 'ERROR: unsupported architecture: %s\n' "$arch" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl" -o "$tmp/kubectl"
curl -fsSL "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl.sha256" -o "$tmp/kubectl.sha256"
printf '%s  %s\n' "$(cat "$tmp/kubectl.sha256")" "$tmp/kubectl" | sha256sum --check --status
install -m 0755 "$tmp/kubectl" /usr/local/bin/kubectl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o "$tmp/helm.asc"
gpg --dearmor --yes -o /etc/apt/keyrings/helm.gpg "$tmp/helm.asc"
chmod a+r /etc/apt/keyrings/helm.gpg
printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main' > /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install helm

kind_version="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name')"
[[ "$kind_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'ERROR: invalid kind release tag.' >&2; exit 3; }
kind_asset='kind-linux-amd64'
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/${kind_asset}" -o "$tmp/kind"
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/${kind_asset}.sha256sum" -o "$tmp/kind.sha256sum"
printf '%s  %s\n' "$(cat "$tmp/kind.sha256sum")" "$tmp/kind" | sha256sum --check --status
install -m 0755 "$tmp/kind" /usr/local/bin/kind

kubectl version --client
helm version --short
kind version
