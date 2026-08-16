#!/usr/bin/env bash

# Live operator progress for real mutating actions.
# Technical command lines remain in commands.log/main.log/modules.log.
# This layer writes only short human labels to the controlling terminal.

UI_LIVE_MODULE_ID=''
UI_LIVE_ACTION_LABEL=''

ui_live_progress_enabled() {
  declare -F ui_is_operator >/dev/null 2>&1 || return 1
  ui_is_operator || return 1
  is_true "${DRY_RUN:-true}" && return 1
  is_true "${REAL_MACHINE_APPROVED:-false}" || return 1
  [[ -w /dev/tty ]] 2>/dev/null
}

ui_live_action_label() {
  local scope="$1" rendered="$2" key
  key="${UI_STEP_ID:-unknown}:$rendered"

  case "$key" in
    host.os_updates:*apt-get\ update*) printf '%s\n' 'Actualisation des dépôts Ubuntu' ;;
    host.os_updates:*dist-upgrade*) printf '%s\n' 'Installation des mises à jour Ubuntu' ;;

    host.firmware_microcode:*) printf '%s\n' 'Microcode AMD et firmware système' ;;
    host.graphics:*) printf '%s\n' 'Pile Intel Arc / Mesa / Vulkan' ;;

    host.multimedia:*install_vlc_snap.sh*) printf '%s\n' 'VLC — canal VideoLAN Snap' ;;
    host.multimedia:*) printf '%s\n' 'FFmpeg, GStreamer et pile multimédia' ;;

    host.apps:*remove_retired_desktop_apps.sh*) printf '%s\n' 'Nettoyage des applications retirées' ;;
    host.apps:*apt-get*install*) printf '%s\n' 'Paquets Ubuntu — FileZilla, Remmina, LibreOffice…' ;;
    host.apps:*install_mozilla_repo.sh*) printf '%s\n' 'Firefox — dépôt officiel Mozilla' ;;
    host.apps:*install_proton_mail.sh*) printf '%s\n' 'Proton Mail Desktop' ;;
    host.apps:*install_vscode_repo.sh*) printf '%s\n' 'Visual Studio Code — dépôt Microsoft' ;;
    host.apps:*code*--install-extension*) printf '%s\n' 'VS Code — extension Remote SSH' ;;
    host.apps:*install_brave_repo.sh*) printf '%s\n' 'Brave Browser' ;;
    host.apps:*install_onlyoffice_repo.sh*) printf '%s\n' 'ONLYOFFICE Desktop Editors' ;;
    host.apps:*install_flatpak_apps.sh*) printf '%s\n' 'Bitwarden, OBS Studio et Extension Manager' ;;
    host.apps:*install_drawio_release.sh*) printf '%s\n' 'draw.io Desktop' ;;
    host.apps:*) printf '%s\n' 'Configuration des applications desktop' ;;

    host.terminal:*) printf '%s\n' 'Terminal, Bash et outils SSH' ;;
    host.gaming:*dpkg*--add-architecture*) printf '%s\n' 'Activation de l’architecture i386' ;;
    host.gaming:*apt-get\ update*) printf '%s\n' 'Actualisation des dépôts pour i386' ;;
    host.gaming:*install_steam_repo.sh*) printf '%s\n' 'Steam — dépôt officiel Valve' ;;
    host.gaming:*) printf '%s\n' 'GameMode, Gamescope et MangoHud' ;;
    host.observability:*) printf '%s\n' 'Outils de diagnostic matériel' ;;

    kvm.stack:*apt-get*install*) printf '%s\n' 'QEMU, libvirt et outils KVM' ;;
    kvm.stack:*usermod*) printf '%s\n' 'Droits utilisateur libvirt / KVM' ;;
    kvm.firmware:*) printf '%s\n' 'UEFI OVMF et TPM virtuel' ;;
    kvm.storage:*install\ -d*) printf '%s\n' 'Préparation du stockage des VM' ;;
    kvm.storage:*pool-define*) printf '%s\n' 'Définition du pool devops-data' ;;
    kvm.storage:*pool-start*) printf '%s\n' 'Démarrage du pool devops-data' ;;
    kvm.storage:*pool-autostart*) printf '%s\n' 'Activation automatique du pool' ;;
    kvm.storage:*) printf '%s\n' 'Configuration du stockage KVM' ;;
    kvm.network:*apt-get*install*) printf '%s\n' 'Composants réseau et pare-feu KVM' ;;
    kvm.network:*kvm_network_guard.sh*) printf '%s\n' 'Installation du garde réseau fail-closed' ;;
    kvm.network:*systemctl*) printf '%s\n' 'Activation du garde réseau KVM' ;;
    kvm.network:*net-define*) printf '%s\n' 'Définition du réseau devops-nat' ;;
    kvm.network:*net-start*) printf '%s\n' 'Démarrage du réseau devops-nat' ;;
    kvm.network:*net-autostart*) printf '%s\n' 'Activation automatique du réseau' ;;
    kvm.network:*) printf '%s\n' 'Configuration du réseau KVM isolé' ;;
    kvm.catalog:*) printf '%s\n' 'Catalogue officiel des images Ubuntu' ;;

    vm.cloud_init:*cloud-localds*) printf '%s\n' 'Génération du disque cloud-init' ;;
    vm.cloud_init:*) printf '%s\n' 'Préparation cloud-init Ubuntu Server' ;;
    vm.provision:*fetch_ubuntu_2604_cloud_image.sh*) printf '%s\n' 'Téléchargement de l’image Ubuntu Server 26.04' ;;
    vm.provision:*qemu-img*resize*) printf '%s\n' 'Dimensionnement du disque VM à 200 Gio' ;;
    vm.provision:*virt-install*) printf '%s\n' 'Création de la VM ubuntu-devops' ;;
    vm.provision:*) printf '%s\n' 'Provisionnement de la VM ubuntu-devops' ;;
    vm.base:*) printf '%s\n' 'Outils système dans VM_DEVOPS' ;;
    vm.git:*) printf '%s\n' 'Git et OpenSSH dans VM_DEVOPS' ;;
    vm.cloud_clis:*) printf '%s\n' 'CLI AWS et Azure dans VM_DEVOPS' ;;
    vm.iac:*) printf '%s\n' 'Terraform et Ansible dans VM_DEVOPS' ;;
    vm.docker:*) printf '%s\n' 'Docker Engine dans VM_DEVOPS' ;;
    vm.kubernetes:*) printf '%s\n' 'Kubernetes, Helm et kind dans VM_DEVOPS' ;;
    vm.devsecops:*) printf '%s\n' 'Outils DevSecOps dans VM_DEVOPS' ;;

    *)
      case "$rendered" in
        *apt-get\ update*) printf '%s\n' 'Actualisation des dépôts' ;;
        *apt-get*install*) printf '%s\n' "Installation des composants — $scope" ;;
        *) printf '%s\n' "Configuration — $scope" ;;
      esac
      ;;
  esac
}

ui_live_action_format() {
  local label="$1" status="$2" status_text prefix dots_count dots=''
  status_text="$(ui_status_text "$status")"
  prefix="├─ $label"
  dots_count=$((58 - ${#prefix} - ${#status_text}))
  (( dots_count < 3 )) && dots_count=3
  printf -v dots '%*s' "$dots_count" ''
  dots="${dots// /.}"
  printf '          %s %s %s' "$prefix" "$dots" "$status_text"
}

ui_live_action_begin() {
  local label="$1"
  ui_live_progress_enabled || return 0

  if [[ "${UI_LIVE_MODULE_ID:-}" != "${UI_STEP_ID:-}" ]]; then
    # ui_step_begin keeps the module line open with CR on an interactive TTY.
    # Finalize that line once, then show live sub-actions beneath it.
    printf '\n' > /dev/tty
    UI_LIVE_MODULE_ID="${UI_STEP_ID:-unknown}"
  fi

  UI_LIVE_ACTION_LABEL="$label"
  ui_live_action_format "$label" RUNNING > /dev/tty
  printf '\r' > /dev/tty
}

ui_live_action_end() {
  local status="$1"
  ui_live_progress_enabled || return 0
  [[ -n "${UI_LIVE_ACTION_LABEL:-}" ]] || return 0
  printf '\r\033[2K' > /dev/tty
  ui_live_action_format "$UI_LIVE_ACTION_LABEL" "$status" > /dev/tty
  printf '\n' > /dev/tty
  UI_LIVE_ACTION_LABEL=''
}

ui_live_action_ok() {
  ui_live_action_end OK
}

ui_live_action_fail() {
  ui_live_action_end FAIL
}
