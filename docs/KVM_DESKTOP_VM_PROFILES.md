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
- VirtIO pour disque/réseau lorsque le guest le supporte ;
- aucune VM optionnelle ne contourne l'isolation réseau du projet ;
- aucun GPU passthrough/VFIO : le GPU Intel Arc reste propriété du HOST.

Les valeurs sont définies dans `config/vm-profiles.conf`. Le helper `scripts/kvm/vm-profile` permet d'afficher un profil, de prévisualiser la commande et de créer explicitement la VM à la demande.

## Ubuntu Desktop 26.04 LTS

Profil par défaut : **6 vCPU, 8 Gio RAM, 100 Gio QCOW2**, UEFI, CPU `host-passthrough`, disque/réseau VirtIO sur `devops-nat`.

### Accélération graphique retenue

Le profil utilise le chemin graphique partagé le plus performant et maintenable sans retirer un GPU au HOST :

- VirtIO-GPU avec accélération 3D ;
- VirGL/OpenGL côté HOST ;
- SPICE avec GL activé ;
- sélection dynamique du render node Intel ;
- canal SPICE agent pour presse-papiers et intégration de session ;
- redirection USB ;
- audio virtuel.

Le render node n'est **jamais supposé être `/dev/dri/renderD128`**. Le helper parcourt les DRM render nodes et choisit celui dont le vendor PCI est Intel (`0x8086`). C'est nécessaire sur une machine exposant à la fois l'iGPU Ryzen et l'Intel Arc B580, car l'ordre `renderD128`, `renderD129`, etc. n'est pas un contrat stable.

Ce chemin conserve l'Arc disponible pour GNOME/Wayland sur le HOST tout en fournissant une accélération 3D matérielle partagée à la VM. **Le passthrough PCI/VFIO n'est ni implémenté, ni supporté, ni autorisé par ce projet.**

Prévisualisation :

```bash
scripts/kvm/vm-profile show ubuntu-desktop
scripts/kvm/vm-profile command ubuntu-desktop \
  --iso /chemin/ubuntu-26.04-desktop-amd64.iso
```

Création réelle à la demande :

```bash
scripts/kvm/vm-profile create ubuntu-desktop \
  --iso /chemin/ubuntu-26.04-desktop-amd64.iso
```

La création exige un TTY interactif et la confirmation exacte `CREATE_ubuntu-desktop`. Le helper vérifie l'ISO, le réseau, le pool, l'absence d'une VM/volume du même nom et le render node Intel avant la première mutation.

## Windows 11

Profil par défaut : **8 vCPU, 16 Gio RAM, 200 Gio QCOW2**, Q35, CPU `host-passthrough`, réseau VirtIO sur `devops-nat`.

Le contrat impose :

- UEFI avec Secure Boot et clés enrôlées ;
- TPM 2.0 émulé par `swtpm` ;
- disque VirtIO ;
- réseau VirtIO ;
- ISO VirtIO obligatoire pour fournir les pilotes pendant l'installation ;
- SPICE/virtio-video ;
- canal SPICE agent, audio et redirection USB.

Aucun bypass des exigences Windows 11 n'est prévu.

Prévisualisation :

```bash
scripts/kvm/vm-profile show windows-11
scripts/kvm/vm-profile command windows-11 \
  --iso /chemin/Windows11.iso \
  --virtio-iso /chemin/virtio-win.iso
```

Création réelle :

```bash
scripts/kvm/vm-profile create windows-11 \
  --iso /chemin/Windows11.iso \
  --virtio-iso /chemin/virtio-win.iso
```

La confirmation attendue est `CREATE_windows-11`.

## Sécurité et rollback de création

Le mode `command` est non mutateur. Le mode `create` :

1. valide les médias, le pool et `devops-nat` ;
2. refuse un nom de VM ou un volume déjà existant ;
3. exige une confirmation interactive exacte ;
4. crée un volume dédié `<nom>.qcow2` ;
5. lance `virt-install` ;
6. si `virt-install` échoue, détruit/undefine uniquement le domaine créé par cette opération et supprime uniquement son volume nouvellement créé.

Cette propriété évite de toucher aux VM ou volumes préexistants lors d'un rollback.

## Ressources de la workstation

Les profils sont dimensionnés pour le HOST 48 Gio / Ryzen 7 7700. Ce sont des valeurs par défaut. `ubuntu-devops` utilise 16 Gio, Windows 11 16 Gio et Ubuntu Desktop 8 Gio : les démarrer simultanément consommerait déjà 40 Gio configurés. Il faut conserver une marge pour Ubuntu GNOME et les applications du HOST.

## Réseau

Les profils utilisent `devops-nat` : `192.168.50.0/24`, passerelle `192.168.50.254`, DHCP `.100-.200`, DNS Quad9/Cloudflare. HOST ↔ VM, VM ↔ VM et VM → Internet sont autorisés ; VM → LAN physique, LAN → VM et Internet → VM restent bloqués.

## Cycle recommandé

1. choisir le profil ;
2. obtenir et vérifier les médias d'installation ;
3. contrôler les ressources HOST ;
4. contrôler `devops-nat` et `devops-data` ;
5. utiliser `vm-profile show` ;
6. utiliser `vm-profile command` pour relire la commande ;
7. utiliser `vm-profile create` lorsque l'opération est validée ;
8. terminer l'installation dans la console graphique ;
9. installer les outils/agents invités nécessaires ;
10. exécuter les postchecks réseau, stockage et graphique.
