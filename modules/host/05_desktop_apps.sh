#!/usr/bin/env bash
set -Eeuo pipefail

host_apps_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_brave_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_drawio_release.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

host_apps_plan() {
  cat <<'EOF'
COMPLETE DESKTOP APPLICATION PLAN:
- Ubuntu packages: OBS Studio, FileZilla, PDF Arranger, Remmina RDP/VNC, LibreOffice
- Nautilus extensions: administrative actions and image resize/rotate
- GNOME Extension Manager for explicit user-managed extension lifecycle; no automatic extension sprawl
- maintained Markdown editor: Ghostwriter from Ubuntu 26.04
- VS Code from Microsoft's signed official APT repository + Remote SSH extension
- Brave from Brave's signed official APT repository
- Bitwarden Desktop and ONLYOFFICE Desktop Editors through their documented Flathub distributions
- draw.io from the official jgraph/drawio-desktop GitHub release with GitHub SHA-256 asset digest verification
- MarkText is not auto-installed because its official stable upstream is stale; Ghostwriter is the safe default
- no curl|bash installer and no apt-key usage
- all mutations are executed only through run_mutating
EOF
}

host_apps_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ca-certificates curl gnupg jq flatpak \
    obs-studio filezilla pdfarranger \
    remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret \
    libreoffice libreoffice-gnome \
    nautilus-admin nautilus-image-converter \
    gnome-shell-extension-manager ghostwriter || return "$EXIT_APPLY_FAILED"

  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_vscode_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST code --install-extension ms-vscode-remote.remote-ssh --force || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_brave_repo.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_flatpak_apps.sh" || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_drawio_release.sh" || return "$EXIT_APPLY_FAILED"
}

host_apps_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: desktop applications postcheck deferred'
    return 0
  fi

  local cmd
  for cmd in code brave-browser obs filezilla remmina libreoffice pdfarranger ghostwriter flatpak; do
    command -v "$cmd" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done
  dpkg-query -W gnome-shell-extension-manager >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  code --list-extensions | grep -Fxqi 'ms-vscode-remote.remote-ssh' || return "$EXIT_POSTCHECK_FAILED"
  flatpak info --system com.bitwarden.desktop >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  flatpak info --system org.onlyoffice.desktopeditors >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  dpkg-query -W drawio >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
