#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

# User explicitly retired these applications from the workstation desired state.
# Package removal only: user profiles, mail data and configuration directories
# are intentionally preserved.

if command -v apt-get >/dev/null 2>&1; then
  apt_remove=()
  for package in thunderbird pdfarranger; do
    if dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null | grep -Fxq 'install ok installed'; then
      apt_remove+=("$package")
    fi
  done
  if ((${#apt_remove[@]} > 0)); then
    DEBIAN_FRONTEND=noninteractive apt-get -y remove "${apt_remove[@]}"
  fi
fi

if command -v snap >/dev/null 2>&1 && snap list thunderbird >/dev/null 2>&1; then
  snap remove thunderbird
fi

if command -v flatpak >/dev/null 2>&1; then
  for app_id in org.mozilla.Thunderbird com.github.jeromerobert.pdfarranger; do
    if flatpak info --system "$app_id" >/dev/null 2>&1; then
      flatpak uninstall --system -y "$app_id"
    fi
  done

  desktop_user="${SUDO_USER:-}"
  if [[ -n "$desktop_user" && "$desktop_user" != root ]] && id "$desktop_user" >/dev/null 2>&1; then
    for app_id in org.mozilla.Thunderbird com.github.jeromerobert.pdfarranger; do
      if sudo -u "$desktop_user" flatpak info --user "$app_id" >/dev/null 2>&1; then
        sudo -u "$desktop_user" flatpak uninstall --user -y "$app_id"
      fi
    done
  fi
fi

printf '%s\n' 'Retired applications removed: Thunderbird and PDF Arranger (when present).'
printf '%s\n' 'User data and Thunderbird profiles were preserved.'
