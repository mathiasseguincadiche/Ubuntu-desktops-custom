# VM Desktop optionnelles sous KVM

Le socle KVM de la workstation peut héberger des VM graphiques en plus de `ubuntu-devops`. Ces profils sont **optionnels** : l'installation automatique de la workstation ne crée que la VM DevOps Ubuntu Server prévue par le plan principal.

## Profils

| Profil | vCPU | RAM | Disque | Usage |
|---|---:|---:|---:|---|
| `ubuntu-devops` | 8 | 16 Go | 200 Go | Ubuntu Server 26.04, CLI, DevOps |
| `ubuntu-desktop` | 6 | 8 Go | 100 Go | Ubuntu Desktop 26.04 / GNOME |
| `windows-11` | 8 | 16 Go | 200 Go | Windows 11 desktop |

Les profils Desktop utilisent `devops-nat` par défaut et ne sont pas en autostart.

## Ubuntu Desktop : accélération graphique

Le profil Ubuntu Desktop utilise le meilleur chemin graphique partagé et maintenable sans retirer le GPU physique au HOST :

- machine Q35 et CPU `host-passthrough` ;
- virtio-gpu / virtio-video avec accélération 3D ;
- VirGL ;
- SPICE avec OpenGL ;
- render node HOST `/dev/dri/renderD128` ;
- PipeWire pour l'audio ;
- canaux SPICE et redirection USB.

Le passthrough VFIO de l'Intel Arc B580 n'est pas activé par défaut : la workstation HOST utilise ce GPU pour GNOME/Wayland. Un passthrough complet demanderait un GPU distinct pour le HOST ou une architecture GPU dédiée et constitue un autre contrat.

Avant de créer cette VM, vérifier :

```bash
ls -l /dev/dri/renderD128
virsh -c qemu:///system version
scripts/kvm/vm-profile show ubuntu-desktop
```

Pour générer la commande `virt-install` sans l'exécuter :

```bash
scripts/kvm/vm-profile command ubuntu-desktop --iso /chemin/ubuntu-26.04-desktop-amd64.iso
```

## Windows 11

Le profil Windows 11 prévoit :

- Q35 ;
- 8 vCPU / 16 Go ;
- disque QCOW2 200 Go sur bus VirtIO ;
- UEFI/Secure Boot comme cible de firmware ;
- TPM 2.0 émulé par `swtpm` ;
- réseau VirtIO sur `devops-nat` ;
- SPICE, virtio-video, audio et redirection USB ;
- ISO VirtIO obligatoire pour fournir les pilotes de stockage/réseau pendant l'installation si nécessaire.

Prévisualisation :

```bash
scripts/kvm/vm-profile show windows-11
scripts/kvm/vm-profile command windows-11 \
  --iso /chemin/Windows11.iso \
  --virtio-iso /chemin/virtio-win.iso
```

Le helper `vm-profile` ne crée jamais la VM : il imprime la commande révisée afin que l'opérateur puisse la contrôler avant exécution.

## Ressources

Les valeurs sont des profils par défaut, pas des limites. Éviter de surallouer simultanément les VM sur la workstation 48 Go. Par exemple, `ubuntu-devops` (16 Go) + Windows 11 (16 Go) + Ubuntu Desktop (8 Go) représente déjà 40 Go de RAM configurée ; laisser une marge suffisante au HOST et ne démarrer ensemble que les VM nécessaires.

## Réseau

Les VM Desktop héritent par défaut du même réseau isolé :

- `192.168.50.0/24` ;
- passerelle HOST `192.168.50.254` ;
- DHCP `192.168.50.100-200` ;
- DNS `9.9.9.9` et `1.1.1.1` ;
- HOST ↔ VM et VM ↔ VM autorisés ;
- VM → Internet autorisé ;
- accès au LAN physique et forwarding entrant bloqués.

## Administration

L'administration reste CLI-first :

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system start ubuntu-desktop
virsh -c qemu:///system shutdown ubuntu-desktop
virsh -c qemu:///system start windows-11
```

`virt-manager` et `virt-viewer` restent disponibles pour la console graphique et les inspections ponctuelles.
