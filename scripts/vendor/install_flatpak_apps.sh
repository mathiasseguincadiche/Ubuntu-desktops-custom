#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v flatpak >/dev/null 2>&1 || { printf '%s\n' 'ERROR: flatpak is required.' >&2; exit 1; }

conflicts=()
for package in obs-studio gnome-shell-extension-manager; do
  if dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null | grep -Fxq 'install ok installed'; then
    conflicts+=("$package:apt")
  fi
done
if command -v snap >/dev/null 2>&1; then
  for app in bitwarden obs-studio; do
    if snap list "$app" >/dev/null 2>&1; then
      conflicts+=("$app:snap")
    fi
  done
fi
if ((${#conflicts[@]} > 0)); then
  printf 'ERROR: packaging migration required before Flatpak convergence: %s\n' "${conflicts[*]}" >&2
  printf '%s\n' 'Remove the conflicting package explicitly after reviewing the read-only inventory; no automatic uninstall is performed.' >&2
  exit 1
fi

flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --system -y flathub \
  com.bitwarden.desktop \
  com.obsproject.Studio \
  com.mattjakeman.ExtensionManager
