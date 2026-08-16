# Profils KVM pour VM graphiques

Les VM graphiques sont optionnelles. Elles ne sont pas créées pendant l'installation automatique de la workstation : la VM provisionnée automatiquement reste `ubuntu-devops`, Ubuntu Server 26.04 LTS sans environnement graphique.

## Principes communs

- KVM/QEMU + libvirt ;
- administration CLI-first avec `virsh` et `virt-install` ;
- `virt-manager` et `virt-viewer` pour la console graphique et l'inspection ;
- pool `devops-data` ;
- réseau `devops-nat` ;
- autostart désactivé ;
- CPU `host-passthrough` ;
- machine Q35 ;
- disques QCOW2 ;
- aucune VM optionnelle ne contourne l'isolation réseau du projet.

Les valeurs sont définies dans `config/vm-profiles.conf`. Le helper `scripts/kvm/vm-profile` affiche les profils et génère une commande `virt-install` révisable sans jamais l'exécuter lui-même.

## Ubuntu Desktop 26.04 LTS

Profil : 6 vCPU, 8 Gio RAM, 100 Gio QCOW2, UEFI, réseau VirtIO sur `devops-nat`.

### Accélération graphique retenue

Le profil utilise le chemin graphique partagé le plus performant et maintenable avec l'Intel Arc B580 conservée par le HOST :

- virtio-gpu/virtio-video avec accélération 3D ;
- VirGL/OpenGL ;
- SPICE GL ;
- render node DRM HOST `/dev/dri/renderD128` ;
- CPU `host-passthrough` ;
- audio PipeWire ;
- canal SPICE agent pour presse-papiers/redimensionnement ;
- redirection USB.

Ce choix permet l'accélération 3D dans la VM sans retirer la B580 à GNOME/Wayland sur le HOST. Le passthrough PCI/VFIO complet n'est pas le profil par défaut : avec une seule carte graphique principale, il ferait perdre le GPU au HOST pendant l'utilisation de la VM et impose un contrat IOMMU/reset distinct. Il pourra être traité séparément si un second GPU est ajouté.

Contrôles :

```bash
ls -l /dev/dri/renderD128
scripts/kvm/vm-profile show ubuntu-desktop
scripts/kvm/vm-profile command ubuntu-desktop --iso /chemin/ubuntu-26.04-desktop-amd64.iso
```

La dernière commande ne crée rien : elle imprime uniquement la commande `virt-install`.

## Windows 11

Profil : 8 vCPU, 16 Gio RAM, 200 Gio QCOW2, Q35, CPU `host-passthrough`, réseau VirtIO sur `devops-nat`.

Le contrat prévoit :

- UEFI avec Secure Boot comme cible ;
- TPM 2.0 émulé par `swtpm` ;
- disque VirtIO ;
- réseau VirtIO ;
- ISO VirtIO obligatoire ;
- SPICE/virtio-video ;
- agent invité, audio et redirection USB.

Aucun bypass des exigences Windows 11 n'est prévu.

Prévisualisation :

```bash
scripts/kvm/vm-profile show windows-11
scripts/kvm/vm-profile command windows-11 \
  --iso /chemin/Windows11.iso \
  --virtio-iso /chemin/virtio-win.iso
```

## Ressources de la workstation

Les profils sont dimensionnés pour le HOST 48 Gio / Ryzen 7 7700. Ce sont des valeurs par défaut. Ne pas démarrer toutes les VM lourdes simultanément sans conserver une marge suffisante pour le HOST : `ubuntu-devops` 16 Gio + Windows 11 16 Gio + Ubuntu Desktop 8 Gio représente déjà 40 Gio configurés.

## Réseau

Les profils utilisent `devops-nat` : `192.168.50.0/24`, passerelle `192.168.50.254`, DHCP `.100-.200`, DNS Quad9/Cloudflare. HOST ↔ VM, VM ↔ VM et VM → Internet sont autorisés ; VM → LAN physique, LAN → VM et Internet → VM restent bloqués.

## Cycle de création

1. choisir le profil ;
2. résoudre/vérifier l'ISO ;
3. contrôler les ressources HOST ;
4. contrôler `devops-nat` ;
5. afficher la configuration/commande ;
6. faire valider l'opération par l'opérateur ;
7. créer le disque et la VM ;
8. démarrer l'installation ;
9. exécuter les postchecks réseau/graphique/libvirt.

Toute future automatisation de création réelle doit rester transactionnelle : un échec doit nettoyer uniquement les ressources créées par l'opération et ne jamais toucher aux VM préexistantes.
