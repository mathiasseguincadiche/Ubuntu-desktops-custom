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

@test "VS Code uses Microsoft signed repository" {
  grep -F 'https://packages.microsoft.com/keys/microsoft.asc' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
  grep -F 'https://packages.microsoft.com/repos/code' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
  grep -F 'Signed-By:' "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh"
}

@test "Brave uses official signed repository files" {
  grep -F 'brave-browser-archive-keyring.gpg' "$REPO_ROOT/scripts/vendor/install_brave_repo.sh"
  grep -F 'brave-browser.sources' "$REPO_ROOT/scripts/vendor/install_brave_repo.sh"
}

@test "OBS uses the official stable Ubuntu PPA" {
  grep -F 'ppa:obsproject/obs-studio' "$REPO_ROOT/scripts/vendor/install_obs_repo.sh"
  grep -F 'apt-get -y install obs-studio' "$REPO_ROOT/scripts/vendor/install_obs_repo.sh"
}

@test "ONLYOFFICE uses its signed official APT repository" {
  grep -F 'https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'signed-by=' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'https://download.onlyoffice.com/repo/debian squeeze main' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
  grep -F 'apt-get -y install onlyoffice-desktopeditors' "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh"
}

@test "drawio installer requires GitHub SHA256 digest" {
  grep -F 'api.github.com/repos/jgraph/drawio-desktop/releases/latest' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
  grep -F '[[ "$digest" == sha256:* ]]' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
  grep -F 'sha256sum -c -' "$REPO_ROOT/scripts/vendor/install_drawio_release.sh"
}

@test "Flatpak vendor list is restricted to Bitwarden" {
  grep -F 'com.bitwarden.desktop' "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh"
  run grep -E 'flatpak install.*(org\.onlyoffice\.desktopeditors|com\.jgraph\.drawio|marktext)' "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh"
  [ "$status" -ne 0 ]
}
