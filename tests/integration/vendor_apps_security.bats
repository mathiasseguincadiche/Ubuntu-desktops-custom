#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "vendor installers never use curl pipe shell" {
  run grep -R -n -E 'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash)' "$REPO_ROOT/scripts/vendor"
  [ "$status" -ne 0 ]
}

@test "vendor installers never use apt-key" {
  run grep -R -n -E '(^|[[:space:]])apt-key([[:space:]]|$)' "$REPO_ROOT/scripts/vendor"
  [ "$status" -ne 0 ]
}

@test "Mozilla installer is Firefox-only and uses signed repository" {
  script="$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh"
  grep -F 'https://packages.mozilla.org/apt/repo-signing-key.gpg' "$script"
  grep -F '35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3' "$script"
  grep -F 'Suites: mozilla' "$script"
  ! grep -Fq 'thunderbird-deb' "$script"
  grep -F 'Pin-Priority: 1000' "$script"
  grep -F 'apt-get -y install firefox' "$script"
  ! grep -Eq 'install firefox thunderbird' "$script"
}

@test "Proton Mail installer selects Stable DEB and verifies SHA512" {
  script="$REPO_ROOT/scripts/vendor/install_proton_mail.sh"
  grep -F 'https://proton.me/download/mail/linux/version.json' "$script"
  grep -F 'CategoryName == "Stable"' "$script"
  grep -F 'Sha512CheckSum' "$script"
  grep -F 'sha512sum --check --status' "$script"
  grep -F 'dpkg-deb -f "$DEB" Package' "$script"
  grep -F '[[ "$package_name" == proton-mail ]]' "$script"
}

@test "retired app cleanup removes packages and stale DuckDuckGo policy but preserves user data" {
  script="$REPO_ROOT/scripts/vendor/remove_retired_desktop_apps.sh"
  grep -F 'thunderbird pdfarranger' "$script"
  grep -F 'snap remove thunderbird' "$script"
  grep -F 'org.mozilla.Thunderbird' "$script"
  grep -F 'com.github.jeromerobert.pdfarranger' "$script"
  grep -F '20-duckduckgo.json' "$script"
  grep -F 'jid1-ZAdIEUB7XOzOJw@jetpack' "$script"
  grep -F 'User data, Thunderbird profiles and unrelated browser policies were preserved.' "$script"
  run grep -E 'rm -rf.*(thunderbird|\.thunderbird)' "$script"
  [ "$status" -ne 0 ]
}

@test "DuckDuckGo installer is absent" {
  [ ! -e "$REPO_ROOT/scripts/vendor/configure_duckduckgo.sh" ]
}

@test "VS Code uses Microsoft signed repository" {
  grep -F 'https://packages.microsoft.com/keys/microsoft.asc' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
  grep -F 'https://packages.microsoft.com/repos/code' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
  grep -F 'Signed-By:' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
}

@test "Brave uses official signed repository files" {
  grep -F 'brave-browser-archive-keyring.gpg' "$REPO_ROOT/scripts/vendor/install_brave_repo.sh"
  grep -F 'brave-browser.sources' "$REPO_ROOT/scripts/vendor/install_brave_repo.sh"
}

@test "ONLYOFFICE uses its signed official APT repository" {
  grep -F 'https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'signed-by=' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'https://download.onlyoffice.com/repo/debian squeeze main' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'apt-get -y install onlyoffice-desktopeditors' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
}

@test "Steam uses Valve signed stable APT repository" {
  script="$REPO_ROOT/scripts/vendor/install_steam_repo.sh"
  grep -F 'https://repo.steampowered.com/steam/archive/stable/steam.gpg' "$script"
  grep -F 'https://repo.steampowered.com/steam/ stable steam' "$script"
  grep -F 'signed-by=' "$script"
  grep -F 'apt-get -y install steam-launcher' "$script"
}

@test "VLC uses VideoLAN Snap and refuses cross-manager duplicates" {
  script="$REPO_ROOT/scripts/vendor/install_vlc_snap.sh"
  grep -F 'snap install vlc' "$script"
  grep -F 'dpkg-query' "$script"
  grep -F 'org.videolan.VLC' "$script"
}

@test "drawio installer requires GitHub SHA256 digest" {
  grep -F 'api.github.com/repos/jgraph/drawio-desktop/releases/latest' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
  grep -F '[[ "$digest" == sha256:* ]]' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
  grep -F 'sha256sum -c -' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
}

@test "Flatpak vendor list contains only audited upstream applications" {
  script="$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh"
  grep -F 'com.bitwarden.desktop' "$script"
  grep -F 'com.obsproject.Studio' "$script"
  grep -F 'com.mattjakeman.ExtensionManager' "$script"
  run grep -E 'flatpak install.*(org\.onlyoffice\.desktopeditors|com\.jgraph\.drawio|marktext)' "$script"
  [ "$status" -ne 0 ]
}
