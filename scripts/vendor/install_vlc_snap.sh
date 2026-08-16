#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v snap >/dev/null 2>&1 || { printf '%s\n' 'ERROR: snap is required.' >&2; exit 1; }

if dpkg-query -W -f='${Status}\n' vlc 2>/dev/null | grep -Fxq 'install ok installed'; then
  printf '%s\n' 'ERROR: VLC DEB is already installed. Remove or migrate it explicitly before installing the VideoLAN Snap to avoid a duplicate.' >&2
  exit 1
fi
if command -v flatpak >/dev/null 2>&1 && flatpak info --system org.videolan.VLC >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: VLC Flatpak is already installed. Remove or migrate it explicitly before installing the VideoLAN Snap to avoid a duplicate.' >&2
  exit 1
fi
if command -v flatpak >/dev/null 2>&1 && flatpak info --user org.videolan.VLC >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: VLC user Flatpak is already installed. Remove or migrate it explicitly before installing the VideoLAN Snap to avoid a duplicate.' >&2
  exit 1
fi

snap install vlc
