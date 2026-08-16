#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
for cmd in curl apt-get dpkg dpkg-query; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done

conflicts=()
if dpkg-query -W -f='${Status}\n' steam-installer 2>/dev/null | grep -Fxq 'install ok installed'; then
  conflicts+=("steam-installer:apt-ubuntu")
fi
if command -v snap >/dev/null 2>&1 && snap list steam >/dev/null 2>&1; then
  conflicts+=("steam:snap")
fi
if command -v flatpak >/dev/null 2>&1; then
  for scope in system user; do
    if flatpak info --"$scope" com.valvesoftware.Steam >/dev/null 2>&1; then
      conflicts+=("com.valvesoftware.Steam:flatpak-$scope")
    fi
  done
fi
if ((${#conflicts[@]} > 0)); then
  printf 'ERROR: packaging migration required before Valve APT install: %s\n' "${conflicts[*]}" >&2
  printf '%s\n' 'Review the read-only packaging inventory and remove the conflicting packaging explicitly before APPLY.' >&2
  exit 1
fi

KEY_TMP="$(mktemp)"
KEYRING='/usr/share/keyrings/steam.gpg'
SOURCE='/etc/apt/sources.list.d/steam-stable.list'
trap 'rm -f -- "$KEY_TMP"' EXIT

curl -fsSLo "$KEY_TMP" 'https://repo.steampowered.com/steam/archive/stable/steam.gpg'
install -m 0644 "$KEY_TMP" "$KEYRING"
cat > "$SOURCE" <<EOF
deb [arch=amd64,i386 signed-by=$KEYRING] https://repo.steampowered.com/steam/ stable steam
deb-src [arch=amd64,i386 signed-by=$KEYRING] https://repo.steampowered.com/steam/ stable steam
EOF

dpkg --add-architecture i386
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install steam-launcher
