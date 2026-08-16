#!/usr/bin/env bash

# Live operator progress for real mutating actions.
# Technical command lines remain in commands.log/main.log/modules.log.
# This layer writes only short human labels to the controlling terminal.

UI_LIVE_MODULE_ID=''
UI_LIVE_ACTION_LABEL=''
UI_LIVE_ACTION_STARTED_EPOCH=0

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
    host.os_updates:*dist-upgrade*) printf '%s\n' 'Mises à jour Ubuntu (dist-upgrade)' ;;

    host.firmware_microcode:*) printf '%s\n' 'AMD microcode + linux-firmware + fwupd' ;;
    host.graphics:*) printf '%s\n' 'Mesa/Vulkan + Intel VA-API + GPU tools' ;;

    host.multimedia:*install_vlc_snap.sh*) printf '%s\n' 'VLC — canal officiel VideoLAN Snap' ;;
    host.multimedia:*) printf '%s\n' 'FFmpeg + GStreamer + PipeWire/WirePlumber' ;;

    host.apps:*remove_retired_desktop_apps.sh*) printf '%s\n' 'Nettoyage des applications retirées' ;;
    host.apps:*apt-get*install*) printf '%s\n' 'Apps Ubuntu — bureautique, RDP, Markdown' ;;
    host.apps:*install_mozilla_repo.sh*) printf '%s\n' 'Firefox — dépôt officiel Mozilla' ;;
    host.apps:*install_proton_mail.sh*) printf '%s\n' 'Proton Mail Desktop' ;;
    host.apps:*install_vscode_repo.sh*) printf '%s\n' 'Visual Studio Code — dépôt Microsoft' ;;
    host.apps:*code*--install-extension*) printf '%s\n' 'VS Code — extension Remote SSH' ;;
    host.apps:*install_brave_repo.sh*) printf '%s\n' 'Brave Browser — dépôt officiel' ;;
    host.apps:*install_onlyoffice_repo.sh*) printf '%s\n' 'ONLYOFFICE Desktop Editors' ;;
    host.apps:*install_flatpak_apps.sh*) printf '%s\n' 'Bitwarden + OBS + Extension Manager' ;;
    host.apps:*install_drawio_release.sh*) printf '%s\n' 'draw.io Desktop — release vérifiée' ;;
    host.apps:*) printf '%s\n' 'Configuration des applications desktop' ;;

    host.terminal:*) printf '%s\n' 'Ptyxis + SSH + fzf/rg/jq/tree' ;;
    host.gaming:*dpkg*--add-architecture*) printf '%s\n' 'Activation de l’architecture i386' ;;
    host.gaming:*apt-get\ update*) printf '%s\n' 'Actualisation des dépôts pour i386' ;;
    host.gaming:*install_steam_repo.sh*) printf '%s\n' 'Steam — dépôt officiel Valve' ;;
    host.gaming:*apt-get*install*) printf '%s\n' 'Mesa 32 bits + GameMode/Gamescope/MangoHud' ;;
    host.gaming:*) printf '%s\n' 'Configuration du runtime gaming' ;;
    host.observability:*) printf '%s\n' 'NVMe/SMART + capteurs + PCI/USB/audio/webcam' ;;

    kvm.stack:*apt-get*install*) printf '%s\n' 'QEMU/libvirt + virt-install/manager/viewer' ;;
    kvm.stack:*usermod*) printf '%s\n' 'Droits utilisateur libvirt + KVM' ;;
    kvm.stack:*) printf '%s\n' 'Configuration de la pile QEMU/libvirt' ;;
    kvm.firmware:*) printf '%s\n' 'UEFI OVMF + TPM virtuel swtpm' ;;
    kvm.storage:*install\ -d*) printf '%s\n' 'Préparation du stockage des VM' ;;
    kvm.storage:*pool-define*) printf '%s\n' 'Définition du pool devops-data' ;;
    kvm.storage:*pool-start*) printf '%s\n' 'Démarrage du pool devops-data' ;;
    kvm.storage:*pool-autostart*) printf '%s\n' 'Activation automatique du pool' ;;
    kvm.storage:*) printf '%s\n' 'Configuration du stockage KVM' ;;
    kvm.network:*apt-get*install*) printf '%s\n' 'Composants réseau + nftables KVM' ;;
    kvm.network:*kvm_network_guard.sh*) printf '%s\n' 'Installation du garde réseau fail-closed' ;;
    kvm.network:*systemctl*) printf '%s\n' 'Activation du garde réseau KVM' ;;
    kvm.network:*net-define*) printf '%s\n' 'Définition du réseau devops-nat' ;;
    kvm.network:*net-start*) printf '%s\n' 'Démarrage du réseau devops-nat' ;;
    kvm.network:*net-autostart*) printf '%s\n' 'Activation automatique du réseau' ;;
    kvm.network:*) printf '%s\n' 'Configuration du réseau KVM isolé' ;;
    kvm.catalog:*refresh_os_catalog.sh*) printf '%s\n' 'Catalogue Canonical Ubuntu — GPG + SHA256' ;;
    kvm.catalog:*) printf '%s\n' 'Catalogue officiel des images Ubuntu' ;;
    kvm.cli:*) printf '%s\n' 'Outils CLI virsh / virt-install' ;;
    kvm.ssh:*) printf '%s\n' 'Accès SSH HOST vers VM_DEVOPS' ;;

    vm.identity_ssh:*) printf '%s\n' 'Identité réseau + clé SSH de la VM' ;;
    vm.cloud_init:*cloud-localds*) printf '%s\n' 'Seed cloud-init : user/meta/network' ;;
    vm.cloud_init:*) printf '%s\n' 'Préparation cloud-init Ubuntu Server' ;;
    vm.provision:*fetch_ubuntu_2604_cloud_image.sh*) printf '%s\n' 'Image Ubuntu Server 26.04 — vérifiée' ;;
    vm.provision:*qemu-img*resize*) printf '%s\n' 'Dimensionnement du disque VM à 200 Gio' ;;
    vm.provision:*virt-install*) printf '%s\n' 'Création de la VM ubuntu-devops' ;;
    vm.provision:*) printf '%s\n' 'Provisionnement de la VM ubuntu-devops' ;;
    vm.base:*) printf '%s\n' 'Base VM : réseau/debug/Python/tmux' ;;
    vm.git:*) printf '%s\n' 'Git + OpenSSH dans VM_DEVOPS' ;;
    vm.cloud_clis:*) printf '%s\n' 'AWS CLI v2 + Azure CLI' ;;
    vm.iac:*) printf '%s\n' 'Terraform + Ansible' ;;
    vm.docker:*) printf '%s\n' 'Docker Engine + Buildx + Compose' ;;
    vm.kubernetes:*) printf '%s\n' 'kubectl + Helm + kind' ;;
    vm.devsecops:*) printf '%s\n' 'Trivy + Gitleaks + ShellCheck + sécurité IaC' ;;

    *)
      case "$rendered" in
        *apt-get\ update*) printf '%s\n' 'Actualisation des dépôts' ;;
        *apt-get*install*) printf '%s\n' "Installation des composants — $scope" ;;
        *systemctl*) printf '%s\n' "Configuration des services — $scope" ;;
        *virsh*) printf '%s\n' "Configuration libvirt — $scope" ;;
        *) printf '%s\n' "Configuration — $scope" ;;
      esac
      ;;
  esac
}

ui_live_action_format() {
  local label="$1" status="$2" elapsed="${3:-}" status_text prefix dots_count dots=''
  status_text="$(ui_status_text "$status")"
  if [[ -n "$elapsed" ]]; then
    status_text="$status_text · ${elapsed}s"
  fi
  prefix="├─ $label"
  dots_count=$((64 - ${#prefix} - ${#status_text}))
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
  UI_LIVE_ACTION_STARTED_EPOCH="$(date +%s)"
  ui_live_action_format "$label" RUNNING > /dev/tty
  printf '\r' > /dev/tty
}

ui_live_action_end() {
  local status="$1" now elapsed=0
  ui_live_progress_enabled || return 0
  [[ -n "${UI_LIVE_ACTION_LABEL:-}" ]] || return 0
  now="$(date +%s)"
  if [[ "${UI_LIVE_ACTION_STARTED_EPOCH:-0}" =~ ^[0-9]+$ ]] && (( UI_LIVE_ACTION_STARTED_EPOCH > 0 )); then
    elapsed=$((now - UI_LIVE_ACTION_STARTED_EPOCH))
    (( elapsed < 0 )) && elapsed=0
  fi
  printf '\r\033[2K' > /dev/tty
  ui_live_action_format "$UI_LIVE_ACTION_LABEL" "$status" "$elapsed" > /dev/tty
  printf '\n' > /dev/tty
  UI_LIVE_ACTION_LABEL=''
  UI_LIVE_ACTION_STARTED_EPOCH=0
}

ui_live_action_ok() {
  ui_live_action_end OK
}

ui_live_action_fail() {
  ui_live_action_end FAIL
}
