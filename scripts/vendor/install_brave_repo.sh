#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  'https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg'
curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
  'https://brave-browser-apt-release.s3.brave.com/brave-browser.sources'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install brave-browser
