# Profils KVM pour VM graphiques

Les VM graphiques sont des profils optionnels. Elles ne sont pas créées pendant l'installation automatique de la workstation. La VM automatiquement provisionnée reste `ubuntu-devops`, Ubuntu Server 26.04 LTS sans environnement graphique.

## Principes communs

- hyperviseur : KVM/QEMU + libvirt ;
- administration principale : CLI (`virsh`, `virt-install`) ;
- `virt-manager` : interface graphique de secours ;
- stockage : pool `devops-data` ;
- réseau par défaut : `devops-nat` ;
- autostart : désactivé ;
- CPU : `host-passthrough` ;
- machine : Q35 ;
- disque : QCOW2 ;
- les ISO, images et checksums sont résolus par le catalogue avant création ;
- aucune VM optionnelle ne doit contourner les règles d'isolation du réseau KVM.

## Ubuntu Desktop 26.04 LTS

Profil par défaut :

- 6 vCPU ;
- 8 Gio RAM ;
- disque QCOW2 100 Gio ;
- UEFI ;
- virtio-gpu ;
- accélération 3D VirGL/OpenGL ;
- SPICE avec OpenGL ;
- accès au render node DRM du HOST ;
- SPICE agent pour presse-papiers et redimensionnement ;
- redirection USB ;
- audio PipeWire ;
- réseau `devops-nat`.

### Choix graphique

Le profil utilise `virtio-gpu` + VirGL/SPICE GL avec le render node du HOST. C'est le profil graphique accéléré partagé retenu pour une VM Linux Desktop : il évite de retirer l'Intel Arc B580 au HOST, conserve la session GNOME/Wayland du HOST et fournit une accélération 3D matérielle à la VM lorsque la pile Mesa/libvirt/QEMU du HOST la supporte.

Le passthrough PCI/VFIO de la carte graphique n'est pas activé par défaut. Avec une seule Arc B580 destinée au HOST, un passthrough complet ferait perdre la carte au bureau HOST pendant l'utilisation de la VM et impose des contraintes IOMMU/reset supplémentaires. Il pourra rester une fonctionnalité avancée distincte si un second GPU est ajouté plus tard.

## Windows 11

Profil par défaut :

- 8 vCPU ;
- 16 Gio RAM ;
- disque QCOW2 200 Gio ;
- Q35 ;
- UEFI Secure Boot ;
- TPM 2.0 émulé via swtpm ;
- disque VirtIO ;
- réseau VirtIO ;
- ISO pilotes VirtIO obligatoire ;
- SPICE et agent invité ;
- redirection USB ;
- audio PipeWire ;
- réseau `devops-nat`.

Windows 11 doit être installé avec ses exigences normales UEFI/Secure Boot/TPM ; aucun bypass des contrôles matériels Windows n'est prévu.

## Ressources de la workstation

Les profils sont dimensionnés pour rester compatibles avec le HOST 48 Gio / Ryzen 7 7700. Ils représentent des valeurs par défaut, pas une obligation. Avant création, l'outil de gestion doit permettre d'ajuster RAM, vCPU et taille disque tout en refusant une allocation manifestement dangereuse pour le HOST.

## Cycle de création attendu

1. choisir le profil ;
2. résoudre l'ISO/image et son checksum ;
3. contrôler les ressources HOST disponibles ;
4. contrôler le réseau `devops-nat` ;
5. afficher le plan ;
6. demander confirmation ;
7. créer le disque ;
8. créer la VM ;
9. démarrer l'installation ;
10. exécuter les postchecks libvirt/réseau/graphique.

Les opérations de création doivent rester transactionnelles : en cas d'échec avant finalisation, les volumes ou définitions libvirt créés par l'opération doivent être nettoyés sans toucher aux VM préexistantes.
