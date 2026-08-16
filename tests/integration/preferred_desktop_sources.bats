#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "Ubuntu defaults and preferred desktop sources are explicit" {
  policy="$REPO_ROOT/manifests/host/app-packaging-policy.conf"
  grep -Eq '^firefox\|preserve\|snap\|' "$policy"
  grep -Eq '^thunderbird\|preserve\|snap\|' "$policy"
  grep -Eq '^vscode\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^brave\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^obs-studio\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^onlyoffice\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^bitwarden\|managed\|flatpak\|' "$policy"
}

@test "HOST app convergence uses OBS and ONLYOFFICE vendor installers" {
  module="$REPO_ROOT/modules/host/05_desktop_apps.sh"
  grep -Fq 'scripts/vendor/install_obs_repo.sh' "$module"
  grep -Fq 'scripts/vendor/install_onlyoffice_repo.sh' "$module"
  grep -Fq 'flatpak info --system com.bitwarden.desktop' "$module"
  ! grep -Fq 'flatpak info --system org.onlyoffice.desktopeditors' "$module"
}

@test "Flatpak convergence no longer installs ONLYOFFICE" {
  script="$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh"
  grep -Fq 'com.bitwarden.desktop' "$script"
  ! grep -Fq 'org.onlyoffice.desktopeditors' "$script"
}
