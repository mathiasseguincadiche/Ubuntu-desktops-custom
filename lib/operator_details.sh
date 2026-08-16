#!/usr/bin/env bash

# Operator-facing success details for the 41 orchestration modules.
# Loaded after ui.sh so this function intentionally refines ui_module_detail.
# No command execution or security decision belongs in this file.

ui_module_detail() {
  case "$1" in
    host.preflight) printf '%s' 'Ubuntu 26.04 | Ryzen/AMD-V | KVM | stockage | matériel attendu' ;;
    host.os_updates) printf '%s' 'APT metadata + dist-upgrade | aucun changement de release implicite' ;;
    host.firmware_microcode) printf '%s' 'amd64-microcode | linux-firmware | fwupd | aucun flash automatique' ;;
    host.graphics) printf '%s' 'Arc B580 PCI 8086:e20b | driver xe | Vulkan Intel Mesa | probe VA-API' ;;
    host.multimedia) printf '%s' 'FFmpeg | GStreamer base/good/bad/ugly/libav | PipeWire/WirePlumber | VLC' ;;
    host.apps) printf '%s' 'Apps Ubuntu + Firefox Mozilla + Proton + VS Code + Brave + ONLYOFFICE + Flatpak + draw.io' ;;
    host.terminal) printf '%s' 'Ptyxis | Bash completion | OpenSSH | fzf | ripgrep | jq | tree' ;;
    host.gaming) printf '%s' 'i386 | Mesa 32 bits | GameMode | Gamescope | MangoHud/MangoApp | Steam Valve' ;;
    host.observability) printf '%s' 'NVMe/SMART | capteurs | PCI/USB/réseau | audio PipeWire | webcam | rapport santé' ;;
    host.validation) printf '%s' 'Contrats HOST | packaging | scopes | invariants de sécurité validés' ;;

    kvm.preflight) printf '%s' '/dev/kvm | virtualisation CPU | prérequis qemu:///system' ;;
    kvm.stack) printf '%s' 'QEMU | libvirt | virt-install/manager/viewer | SPICE | swtpm | droits libvirt/kvm' ;;
    kvm.firmware) printf '%s' 'OVMF/UEFI | Secure Boot guest-ready | TPM 2.0 virtuel via swtpm' ;;
    kvm.storage) printf '%s' '/data/libvirt/images | pool devops-data | démarrage + autostart' ;;
    kvm.network) printf '%s' 'devops-nat 192.168.50.0/24 | DHCP | DNS | garde nftables fail-closed' ;;
    kvm.catalog) printf '%s' 'Images Canonical Ubuntu | signature GPG | SHA256 | catalogue vérifié' ;;
    kvm.cli) printf '%s' 'virsh + virt-install | administration CLI primaire' ;;
    kvm.ssh) printf '%s' 'Chemin SSH HOST → VM_DEVOPS préparé sans mot de passe' ;;
    kvm.validation) printf '%s' 'Pile KVM | stockage | réseau isolé | catalogue | accès opérateur validés' ;;

    vm.preflight) printf '%s' 'Ressources HOST/KVM | stockage | réseau devops-nat | prérequis VM validés' ;;
    vm.identity_ssh) printf '%s' 'MAC déterministe | réservation DHCP | IP stable | clé SSH uniquement' ;;
    vm.cloud_init) printf '%s' 'user-data | meta-data | network-config | cloud-init key-only' ;;
    vm.provision) printf '%s' 'Ubuntu Server 26.04 | 8 vCPU | 16 Gio RAM | 200 Gio qcow2 | devops-nat' ;;
    vm.base) printf '%s' 'curl/wget/jq/yq | Python/pipx | tmux | réseau/debug | outils système' ;;
    vm.git) printf '%s' 'Git | OpenSSH | accès SCM prêt dans VM_DEVOPS' ;;
    vm.cloud_clis) printf '%s' 'AWS CLI v2 | Azure CLI | sources upstream officielles' ;;
    vm.iac) printf '%s' 'Terraform HashiCorp | Ansible | versions supportées' ;;
    vm.docker) printf '%s' 'Docker Engine | Buildx | Compose plugin | service et droits utilisateur' ;;
    vm.kubernetes) printf '%s' 'kubectl | Helm | kind | binaires/checksums upstream validés' ;;
    vm.devsecops) printf '%s' 'Trivy | Gitleaks | ShellCheck | Hadolint | Checkov' ;;
    vm.validation) printf '%s' 'SSH | réseau | cloud-init | toolchain DevOps | contrats VM validés' ;;

    backup.preflight) printf '%s' 'Politique externe/chiffrée | cible interne refusée | prérequis restauration' ;;
    backup.inventory) printf '%s' 'Inventaire HOST + KVM + VM + configuration critique défini' ;;
    backup.repository) printf '%s' 'Restic chiffré | cible externe obligatoire | secret hors Git' ;;
    backup.host) printf '%s' 'Station Ubuntu + configuration + états de packaging inclus dans le contrat' ;;
    backup.kvm) printf '%s' 'Configuration libvirt | réseaux | pools | métadonnées KVM protégés' ;;
    backup.vm) printf '%s' 'Inventaire VM protégé | copie live qcow2 non sûre explicitement interdite' ;;
    backup.integrity) printf '%s' 'restic check --read-data | rétention 7 daily / 4 weekly / 6 monthly' ;;
    backup.restore) printf '%s' 'Restauration granulaire en staging | comparaison avant promotion' ;;
    backup.dr) printf '%s' 'Ordre DR : réseau isolé → libvirt → VM | reprise fail-closed' ;;
    backup.validation) printf '%s' 'Restore-test + intégrité + preuve BACKUP_VERIFIED exigés avant GO' ;;
    *) printf '%s' '' ;;
  esac
}
