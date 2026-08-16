#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }

# User explicitly retired these applications/integrations from the workstation
# desired state. Package removal only: user profiles, mail data and unrelated
# browser policies are intentionally preserved.

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

# Remove only the DuckDuckGo settings previously managed by this project.
# Other Firefox/Brave policies remain untouched.
FIREFOX_POLICY='/etc/firefox/policies/policies.json'
BRAVE_DDG_POLICY='/etc/brave/policies/managed/20-duckduckgo.json'
DDG_FIREFOX_ID='jid1-ZAdIEUB7XOzOJw@jetpack'

rm -f -- "$BRAVE_DDG_POLICY"

if [[ -s "$FIREFOX_POLICY" ]] && command -v jq >/dev/null 2>&1; then
  tmp_policy="$(mktemp)"
  trap 'rm -f -- "${tmp_policy:-}"' EXIT
  jq --arg addon_id "$DDG_FIREFOX_ID" '
    .policies = (.policies // {}) |
    if .policies.SearchEngines?.Default == "DuckDuckGo"
      then del(.policies.SearchEngines.Default)
      else .
    end |
    if ((.policies.SearchEngines? // {}) | length) == 0
      then del(.policies.SearchEngines)
      else .
    end |
    del(.policies.ExtensionSettings[$addon_id]) |
    if ((.policies.ExtensionSettings? // {}) | length) == 0
      then del(.policies.ExtensionSettings)
      else .
    end
  ' "$FIREFOX_POLICY" > "$tmp_policy"
  install -m 0644 "$tmp_policy" "$FIREFOX_POLICY"
fi

printf '%s\n' 'Retired applications removed: Thunderbird and PDF Arranger (when present).'
printf '%s\n' 'Retired DuckDuckGo managed browser policy removed (when present).'
printf '%s\n' 'User data, Thunderbird profiles and unrelated browser policies were preserved.'
