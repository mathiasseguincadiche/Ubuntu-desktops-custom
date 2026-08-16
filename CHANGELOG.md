# Changelog

## 1.0.0

### Workstation HOST
- Ubuntu Desktop 26.04 LTS comme plateforme native.
- Mise à jour système, firmware et microcode AMD.
- Pile Intel Arc/Mesa/Vulkan/VA-API et diagnostics GPU.
- Codecs et multimédia.
- Socle applicatif desktop, VS Code/Remote SSH, terminal Ptyxis/Bash et outils de bureau.
- Politique applicative auditée par source upstream : Mozilla APT pour Firefox, Proton Mail via DEB officiel vérifié SHA-512, dépôts éditeurs pour VS Code/Brave/ONLYOFFICE/Steam, VideoLAN Snap pour VLC, Flathub upstream pour Bitwarden/OBS/Extension Manager et APT Ubuntu lorsque l'intégration native reste préférable.
- Thunderbird et PDF Arranger retirés du desired state ; aucune intégration DuckDuckGo n'est installée ou imposée par le projet.
- Diagnostic read-only des gestionnaires et de la provenance APT/Flatpak, avec détection `DRIFT`/`DUPLICATE` et migrations cross-manager fail-closed hors retraits explicitement décidés.
- Gate global de packaging : REAL APPLY bloqué avant toute mutation si `DRIFT>0` ou `DUPLICATE>0`; contrôle post-HOST obligatoire avec `PLANNED=0`, `DRIFT=0`, `DUPLICATE=0`.
- Nettoyage des applications retirées contrôlé sur APT/Snap/Flatpak afin d'éviter les paquets desktop parasites.
- Socle gaming Steam, GameMode, Gamescope, MangoHud/MangoApp et runtime Vulkan.
- Observabilité matérielle NVMe/SMART, températures, PCI/USB, réseau, audio et webcam.

### KVM / libvirt
- Administration CLI-first via `qemu:///system`, `virsh`, `virt-install` et `qemu-img`.
- `virt-manager` et `virt-viewer` conservés comme outils graphiques de secours/inspection.
- QEMU/libvirt, UEFI/OVMF, TPM `swtpm`, VirtIO, SPICE/VirGL et `osinfo-db`.
- Pool `devops-data` et réseau `devops-nat` persistants.
- NAT custom `192.168.50.0/24`, passerelle HOST `192.168.50.254`, DHCP `.100-.200`, DNS Quad9/Cloudflare.
- HOST ↔ VM, VM ↔ VM et VM → Internet autorisés ; accès au LAN physique et forwarding entrant bloqués.
- Firewall nftables limité aux objets du projet et comportement fail-closed.
- Catalogue Ubuntu 26.04 vérifié dynamiquement contre les `SHA256SUMS` officiels Canonical.

### VM DevOps
- `ubuntu-devops` : Ubuntu Server 26.04 LTS, 8 vCPU, 16 Gio RAM, 200 Gio QCOW2, cloud-init et SSH par clé.
- Git, Terraform, Ansible/ansible-lint, Docker CE/Buildx/Compose, kubectl, Helm et kind.
- AWS CLI, Azure CLI, Gitleaks, Trivy, Hadolint, ShellCheck et Checkov.
- Image Canonical authentifiée, smoke tests runtime et persistance après reboot validés en laboratoire KVM réel.

### VM graphiques optionnelles
- Ubuntu Desktop 26.04 : 6 vCPU, 8 Gio, 100 Gio, VirtIO-GPU + 3D + VirGL/OpenGL + SPICE GL.
- Sélection dynamique du render node Intel ; aucun chemin `/dev/dri/renderD128` figé.
- Windows 11 : 8 vCPU, 16 Gio, 200 Gio, Q35, UEFI Secure Boot, clés enrôlées, TPM 2.0 et VirtIO.
- Création à la demande avec prévisualisation, confirmation interactive et rollback ciblé.
- GPU passthrough/VFIO explicitement interdit ; l'Intel Arc reste propriété du HOST.

### Backup / Restore
- Restic chiffré avec cible externe obligatoire avant APPLY réel.
- Preuve de backup liée au commit courant et contrôlée en fraîcheur.
- Sauvegarde HOST/KVM/VM, vérification d'intégrité, rétention, restauration granulaire et Disaster Recovery.
- Copie brute à chaud d'un QCOW2 actif interdite.

### Exécution et qualité
- Menu interactif comme point d'entrée recommandé.
- Diagnostic, dry-run intégral, états, logs, rapports, reprise et postchecks par module.
- APPLY fail-closed avec TTY, preflight HOST, preuve dry-run du commit courant, backup vérifié, packaging applicatif propre et confirmations globales/par domaine.
- Tests Bats unitaires/intégration/dry-run, ShellCheck, non-régression, résolution des paquets Ubuntu 26.04 et laboratoire VM réel.
- Documentation d'installation, contrat d'exécution, runbooks HOST/KVM/VM/backup, troubleshooting et guide KVM débutant.
