#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root required.' >&2; exit 1; }

apt-get update
apt-get -y install ca-certificates curl unzip gnupg dirmngr

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# AWS CLI v2: official bundled installer + official detached PGP signature.
aws_zip="$tmp/awscliv2.zip"
aws_sig="$tmp/awscliv2.sig"
aws_fingerprint='FB5DB77FD5C118B80511ADA8A6310ACC4672475C'
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o "$aws_zip"
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig -o "$aws_sig"
export GNUPGHOME="$tmp/gnupg"
install -m 0700 -d "$GNUPGHOME"
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$aws_fingerprint"
actual_fingerprint="$(gpg --batch --with-colons --fingerprint "$aws_fingerprint" | awk -F: '$1=="fpr" {print $10; exit}')"
[[ "$actual_fingerprint" == "$aws_fingerprint" ]] || { printf '%s\n' 'ERROR: AWS CLI signing key fingerprint mismatch.' >&2; exit 2; }
gpg --batch --verify "$aws_sig" "$aws_zip"
unzip -q "$aws_zip" -d "$tmp"
if command -v aws >/dev/null 2>&1; then
  "$tmp/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
else
  "$tmp/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli
fi
aws --version

# Microsoft documents using the latest jammy repository when a newer Ubuntu
# distribution does not yet have a native Azure CLI package.
. /etc/os-release
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
[[ -n "$codename" ]] || { printf '%s\n' 'ERROR: Ubuntu codename unavailable.' >&2; exit 3; }
repo_codename="$codename"
if [[ "$codename" == resolute ]]; then
  repo_codename="${AZURE_CLI_REPO_FALLBACK:-jammy}"
  [[ "$repo_codename" == jammy ]] || { printf '%s\n' 'ERROR: Azure CLI fallback must remain jammy for Resolute unless policy is revised.' >&2; exit 4; }
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$tmp/microsoft.asc"
gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg "$tmp/microsoft.asc"
chmod a+r /etc/apt/keyrings/microsoft.gpg
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ %s main\n' "$repo_codename" > /etc/apt/sources.list.d/azure-cli.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install azure-cli
az version
