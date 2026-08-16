# Guide débutant KVM/libvirt — Ubuntu-desktops-custom

Ce guide sert de mémo CLI pour administrer les VM sans dépendre de virt-manager. Les commandes utilisent `qemu:///system` et le réseau isolé `devops-nat`.

> Règle : commencer par les commandes de lecture. `shutdown` est préféré à `destroy`. Un snapshot ne remplace jamais un backup.

## 1. Architecture des VM

Trois profils de référence existent :

| Profil | Rôle | vCPU | RAM | Disque | Création automatique |
|---|---|---:|---:|---:|---|
| `ubuntu-devops` | Ubuntu Server 26.04 CLI / DevOps | 8 | 16 Go | 200 Go | Oui, par l'installation principale |
| `ubuntu-desktop` | Ubuntu Desktop 26.04 GNOME | 6 | 8 Go | 100 Go | Non, à la demande |
| `windows-11` | Windows 11 Desktop | 8 | 16 Go | 200 Go | Non, à la demande |

Les profils Desktop sont optionnels et n'alourdissent pas l'installation initiale.

## 2. Accélération graphique Ubuntu Desktop

Le profil Ubuntu Desktop utilise la meilleure pile graphique virtuelle générique prévue par le projet sans passthrough GPU :

- machine Q35 et CPU `host-passthrough` ;
- `virtio-gpu` ;
- accélération 3D VirGL/OpenGL ;
- render node DRM du HOST (`/dev/dri/renderD128`) après validation ;
- SPICE pour l'affichage et l'intégration desktop ;
- agent SPICE pour presse-papiers/redimensionnement ;
- PipeWire pour l'audio ;
- redirection USB optionnelle.

Cette configuration accélère réellement le bureau GNOME via le GPU du HOST tout en conservant le GPU physique disponible pour Ubuntu HOST. Ce n'est pas du GPU passthrough/VFIO : une Arc B580 entière ne peut pas être simultanément attribuée exclusivement à une VM et utilisée normalement par le HOST. Le projet privilégie donc virtio-gpu/VirGL pour la VM Desktop générale.

Avant création, le render node doit être détecté et accessible. Le chemin configuré n'est jamais supposé valide sans précheck.

## 3. Windows 11

Le profil Windows 11 prévoit :

- Q35 ;
- CPU `host-passthrough` ;
- 8 vCPU / 16 Go / 200 Go QCOW2 ;
- UEFI avec Secure Boot lorsque le firmware libvirt disponible le permet ;
- TPM 2.0 virtuel ;
- disque et réseau VirtIO ;
- ISO de pilotes VirtIO obligatoire ;
- SPICE/virtio pour l'affichage ;
- audio PipeWire et redirection USB.

L'ISO Windows n'est jamais téléchargée ou contournée silencieusement : elle est fournie au runtime par l'opérateur et validée avant création.

## 4. Afficher les profils sans créer de VM

```bash
./scripts/kvm/create-vm.sh ubuntu-desktop --plan
./scripts/kvm/create-vm.sh windows-11 --plan
```

Le planificateur est volontairement non-mutant tant que les préchecks ISO, firmware, render node et stockage ne sont pas satisfaits.

## 5. Vérifier KVM

```bash
ls -l /dev/kvm
virsh -c qemu:///system version
virsh -c qemu:///system list --all
grep -E -m1 'svm' /proc/cpuinfo
```

## 6. Administration CLI

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system start ubuntu-devops
virsh -c qemu:///system shutdown ubuntu-devops
virsh -c qemu:///system reboot ubuntu-devops
```

Dernier recours uniquement :

```bash
virsh -c qemu:///system destroy ubuntu-devops
```

`destroy` coupe brutalement l'alimentation virtuelle.

## 7. Réseau devops-nat

- réseau : `192.168.50.0/24` ;
- passerelle HOST : `192.168.50.254` ;
- DHCP : `192.168.50.100-200` ;
- DNS : `9.9.9.9`, `1.1.1.1` ;
- HOST ↔ VM : autorisé ;
- VM ↔ VM : autorisé ;
- VM → Internet : autorisé ;
- VM → LAN physique : bloqué ;
- LAN → VM : bloqué ;
- Internet → VM : bloqué.

```bash
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-info devops-nat
virsh -c qemu:///system net-dhcp-leases devops-nat
ip -4 addr show virbr50
```

Ne jamais faire `nft flush ruleset` et ne pas bridger une VM au LAN physique pour contourner le contrat.

## 8. Trouver l'IP et se connecter

```bash
virsh -c qemu:///system domiflist ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
virsh -c qemu:///system net-dhcp-leases devops-nat
ssh ubuntu@<IP_VM>
```

VS Code Remote SSH reste la méthode normale pour travailler dans `ubuntu-devops` depuis le HOST.

## 9. Stockage et XML

```bash
virsh -c qemu:///system pool-list --all
virsh -c qemu:///system vol-list devops-data
virsh -c qemu:///system domblklist ubuntu-devops --details
virsh -c qemu:///system dumpxml ubuntu-devops
```

VM arrêtée :

```bash
qemu-img info /chemin/disque.qcow2
qemu-img check /chemin/disque.qcow2
```

## 10. Snapshots, clonage et backup

```bash
virsh -c qemu:///system snapshot-list ubuntu-devops
```

Un clone doit recevoir une identité libvirt, une MAC et une réservation DHCP distinctes. Ne jamais dupliquer simplement un QCOW2 et démarrer deux VM avec la même identité.

Pour une sauvegarde sûre : arrêt propre, confirmation `shut off`, sauvegarde des métadonnées libvirt et du QCOW2 via le workflow du projet, puis vérification d'intégrité. Une copie brute d'un QCOW2 actif est interdite.

## 11. Dépannage

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domblklist ubuntu-devops --details
virsh -c qemu:///system domiflist ubuntu-devops
virsh -c qemu:///system dumpxml ubuntu-devops
journalctl -b --no-pager | grep -Ei 'libvirt|qemu|kvm'
```

Dans une VM Linux :

```bash
ip route
getent hosts archive.ubuntu.com
ping -c 2 9.9.9.9
ping -c 2 1.1.1.1
```

## 12. Commandes DevOps de référence

Dans `ubuntu-devops` :

```bash
git --version
terraform version
ansible --version
docker version
docker compose version
kubectl version --client
helm version
kind version
aws --version
az version
gitleaks version
trivy --version
shellcheck --version
hadolint --version
checkov --version
docker run --rm hello-world
```

## 13. À retenir

- `ubuntu-devops` reste la VM créée automatiquement par l'installation principale.
- Ubuntu Desktop et Windows 11 sont des profils optionnels à la demande.
- `virsh -c qemu:///system` reste l'interface d'administration principale.
- virt-manager reste une interface graphique de secours/inspection.
- Ubuntu Desktop utilise virtio-gpu + VirGL/3D + SPICE plutôt qu'un passthrough GPU exclusif.
- Windows 11 conserve TPM 2.0, UEFI/Secure Boot et VirtIO.
- Toutes les VM restent par défaut sur `devops-nat`.
- Un snapshot n'est pas un backup.
- Utiliser `RUNBOOK_OPERATIONS.md` pour exploitation et Disaster Recovery.
