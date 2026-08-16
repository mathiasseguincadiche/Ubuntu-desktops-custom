#!/usr/bin/env bash
set -Eeuo pipefail

host_apps_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/remove_retired_desktop_apps.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_proton_mail.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_brave_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_drawio_release.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

host_apps_plan() {
  cat <<'EOF'
COMPLETE DESKTOP APPLICATION PLAN:
- explicitly remove retired Thunderbird and PDF Arranger packages while preserving user profiles/data
- remove any DuckDuckGo browser policy previously managed by this project; no DuckDuckGo integration is installed or enforced
- Ubuntu packages: FileZilla, Remmina RDP/VNC, LibreOffice, Xournal++
- Nautilus extensions: administrative actions and image resize/rotate
- maintained Markdown editor: Ghostwriter from Ubuntu 26.04 because its upstream PPA does not publish Resolute
- native host terminal: Ptyxis remains managed by the Ubuntu/GNOME stack
- Firefox from Mozilla's signed packages.mozilla.org APT repository for Ubuntu Resolute
- Proton Mail from Proton's official Stable Linux DEB, selected from version.json and verified with the publisher SHA-512 before installation
- VS Code from Microsoft's signed official APT repository + Remote SSH extension
- Brave from Brave's signed official APT repository
- ONLYOFFICE Desktop Editors from ONLYOFFICE's signed official Debian/Ubuntu-compatible APT repository
- Bitwarden Desktop, OBS Studio and GNOME Extension Manager from their upstream-supported Flathub distributions
- draw.io from the official jgraph/drawio-desktop GitHub release with GitHub SHA-256 asset digest verification
- cross-manager packaging drift is never auto-removed except for explicitly retired workstation items
- MarkText is not auto-installed because its official stable upstream is stale; Ghostwriter is the safe default
- no curl|bash installer and no apt-key usage
- all mutations are executed only through run_mutating
EOF
}

host_apps_apply() {
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/remove_retired_desktop_apps.sh" || return "$EXIT_APPLY_FAILED"

  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ca-certificates curl gnupg jq flatpak software-properties-common \
    filezilla xournalpp \
    remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret \
    libreoffice libreoffice-gnome \
    nautilus-admin nautilus-image-converter \
    ghostwriter || return "$EXIT_APPLY_FAILED"

  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_mozilla_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_proton_mail.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST code --install-extension ms-vscode-remote.remote-ssh --force || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_brave_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_onlyoffice_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_drawio_release.sh" || return "$EXIT_APPLY_FAILED"
}

host_apps_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: desktop app postcheck deferred'
    return 0
  fi

  local cmd app_id
  for cmd in firefox code brave-browser desktopeditors filezilla remmina libreoffice ghostwriter xournalpp flatpak; do
    command -v "$cmd" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done
  for package in firefox proton-mail onlyoffice-desktopeditors drawio; do
    dpkg-query -W "$package" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done
  ! dpkg-query -W -f='${Status}\n' thunderbird 2>/dev/null | grep -Fxq 'install ok installed' || return "$EXIT_POSTCHECK_FAILED"
  ! dpkg-query -W -f='${Status}\n' pdfarranger 2>/dev/null | grep -Fxq 'install ok installed' || return "$EXIT_POSTCHECK_FAILED"
  if command -v snap >/dev/null 2>&1; then
    ! snap list thunderbird >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    ! snap list pdfarranger >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  fi
  if command -v flatpak >/dev/null 2>&1; then
    for app_id in org.mozilla.Thunderbird com.github.jeromerobert.pdfarranger; do
      ! flatpak info --system "$app_id" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
      ! flatpak info --user "$app_id" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    done
  fi
  [[ ! -e /etc/brave/policies/managed/20-duckduckgo.json ]] || return "$EXIT_POSTCHECK_FAILED"
  if [[ -s /etc/firefox/policies/policies.json ]]; then
    jq -e '.policies.SearchEngines.Default? != "DuckDuckGo" and .policies.ExtensionSettings["jid1-ZAdIEUB7XOzOJw@jetpack"]? == null' \
      /etc/firefox/policies/policies.json >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  fi
  code --list-extensions | grep -Fxqi 'ms-vscode-remote.remote-ssh' || return "$EXIT_POSTCHECK_FAILED"
  flatpak info --system com.bitwarden.desktop >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  flatpak info --system com.obsproject.Studio >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  flatpak info --system com.mattjakeman.ExtensionManager >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
