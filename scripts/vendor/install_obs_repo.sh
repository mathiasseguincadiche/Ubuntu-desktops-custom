#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v add-apt-repository >/dev/null 2>&1 || { printf '%s\n' 'ERROR: add-apt-repository is required.' >&2; exit 1; }

# OBS officially publishes its stable Ubuntu package through this PPA.
# add-apt-repository installs the Launchpad signing material and the source for
# the current Ubuntu series; never substitute another Ubuntu codename.
add-apt-repository -y ppa:obsproject/obs-studio
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install obs-studio
