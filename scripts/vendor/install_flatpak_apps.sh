#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v flatpak >/dev/null 2>&1

flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --system -y flathub com.bitwarden.desktop
flatpak install --system -y flathub org.onlyoffice.desktopeditors
