#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "upstream preferred desktop sources are explicit" {
  policy="$REPO_ROOT/manifests/host/app-packaging-policy.conf"
  grep -Eq '^firefox\|managed\|vendor-apt\|firefox\|firefox\|org\.mozilla\.firefox\|packages\.mozilla\.org\|' "$policy"
  grep -Eq '^proton-mail\|managed\|vendor-deb\|proton-mail\|' "$policy"
  ! grep -Eq '^thunderbird\|' "$policy"
  ! grep -Eq '^pdfarranger\|' "$policy"
  grep -Eq '^vscode\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^brave\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^obs-studio\|managed\|flatpak\|' "$policy"
  grep -Eq '^gnome-extension-manager\|managed\|flatpak\|' "$policy"
  grep -Eq '^onlyoffice\|managed\|vendor-apt\|' "$policy"
  grep -Eq '^bitwarden\|managed\|flatpak\|' "$policy"
  grep -Eq '^steam\|managed\|vendor-apt\|steam-launcher\|' "$policy"
  grep -Eq '^vlc\|managed\|snap\|' "$policy"
  grep -Eq '^xournalpp\|managed\|apt\|' "$policy"
}

@test "HOST app convergence uses Proton Mail and retires Thunderbird PDF Arranger and DuckDuckGo policy" {
  module="$REPO_ROOT/modules/host/05_desktop_apps.sh"
  grep -Fq 'scripts/vendor/remove_retired_desktop_apps.sh' "$module"
  grep -Fq 'scripts/vendor/install_proton_mail.sh' "$module"
  ! grep -Fq 'scripts/vendor/configure_duckduckgo.sh' "$module"
  ! grep -Eq 'apt-get .*install.*pdfarranger' "$module"
  ! grep -Eq 'apt-get .*install.*thunderbird' "$module"
  grep -Fq '20-duckduckgo.json' "$module"
  grep -Fq 'flatpak info --system com.bitwarden.desktop' "$module"
  grep -Fq 'flatpak info --system com.obsproject.Studio' "$module"
  grep -Fq 'flatpak info --system com.mattjakeman.ExtensionManager' "$module"
}

@test "Flatpak convergence is restricted to audited upstream apps" {
  script="$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh"
  grep -Fq 'com.bitwarden.desktop' "$script"
  grep -Fq 'com.obsproject.Studio' "$script"
  grep -Fq 'com.mattjakeman.ExtensionManager' "$script"
  run grep -E 'flatpak install.*(org\.onlyoffice\.desktopeditors|com\.jgraph\.drawio|marktext)' "$script"
  [ "$status" -ne 0 ]
}

@test "gaming and multimedia use Valve Steam and VideoLAN VLC sources" {
  gaming="$REPO_ROOT/modules/host/07_gaming.sh"
  multimedia="$REPO_ROOT/modules/host/04_multimedia_codecs.sh"
  grep -Fq 'scripts/vendor/install_steam_repo.sh' "$gaming"
  ! grep -Eq 'apt-get .*install.*steam-installer' "$gaming"
  grep -Fq 'scripts/vendor/install_vlc_snap.sh' "$multimedia"
  ! grep -Eq 'apt-get .*install.*vlc' "$multimedia"
}
