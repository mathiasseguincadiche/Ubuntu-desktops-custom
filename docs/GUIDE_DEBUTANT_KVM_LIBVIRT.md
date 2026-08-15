# Guide débutant KVM/libvirt — Ubuntu-desktops-custom V1.0.0

Ce guide sert de mémo CLI pour administrer les VM sans dépendre de virt-manager. Les commandes utilisent la connexion système `qemu:///system`, le réseau `devops-nat` et la VM de référence `ubuntu-devops`.

> Règle : commencer par les commandes de lecture. Les commandes marquées **MUTATION** ou **DESTRUCTIF** modifient l'état.

## 1. Comprendre les composants

- **KVM** : accélération de virtualisation du noyau Linux.
- **QEMU** : moteur d'exécution des machines virtuelles.
- **libvirt** : couche d'administration des VM, réseaux et stockages.
- **virsh** : CLI principale de libvirt.
- **virt-manager** : interface graphique optionnelle, utile pour inspection ponctuelle.

Le projet administre les VM principalement avec `virsh -c qemu:///system`.

## 2. Vérifier le socle

```bash
ls -l /dev/kvm
virsh -c qemu:///system version
virsh -c qemu:///system list --all
```

Pour le CPU AMD :

```bash
grep -E -m1 'svm' /proc/cpuinfo
```

## 3. Lister les VM

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domstate ubuntu-devops
```

## 4. Démarrer et arrêter

**MUTATION — démarrage :**

```bash
virsh -c qemu:///system start ubuntu-devops
```

**MUTATION — arrêt propre :**

```bash
virsh -c qemu:///system shutdown ubuntu-devops
```

Attendre l'arrêt :

```bash
watch -n 2 'virsh -c qemu:///system domstate ubuntu-devops'
```

**DESTRUCTIF pour l'état mémoire — dernier recours uniquement :**

```bash
virsh -c qemu:///system destroy ubuntu-devops
```

`destroy` équivaut à couper brutalement l'alimentation virtuelle ; il ne supprime pas le disque mais peut corrompre le guest.

## 5. Redémarrer une VM

```bash
virsh -c qemu:///system reboot ubuntu-devops
```

Si le guest ne répond pas au reboot ACPI, diagnostiquer avant d'utiliser `destroy`.

## 6. Réseau devops-nat

Contrat :

- réseau : `192.168.50.0/24` ;
- passerelle HOST : `192.168.50.254` sur `virbr50` ;
- DHCP : `192.168.50.100-200` ;
- DNS : `9.9.9.9`, `1.1.1.1` ;
- VM → Internet : autorisé ;
- HOST ↔ VM et VM ↔ VM : autorisés ;
- VM → LAN physique, LAN → VM et Internet → VM : bloqués.

Lecture :

```bash
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-info devops-nat
virsh -c qemu:///system net-dumpxml devops-nat
ip -4 addr show virbr50
```

Ne jamais faire `nft flush ruleset` pour dépanner ce réseau.

## 7. Trouver l'IP d'une VM

```bash
virsh -c qemu:///system domiflist ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
virsh -c qemu:///system net-dhcp-leases devops-nat
```

La réservation DHCP déterministe est la méthode de référence du projet.

## 8. SSH vers ubuntu-devops

```bash
ssh ubuntu@<IP_VM>
```

Diagnostic SSH :

```bash
ssh -vv ubuntu@<IP_VM>
```

Ne jamais placer une clé privée SSH dans Git.

## 9. VS Code Remote SSH

Sur le HOST, installer/utiliser VS Code avec l'extension Remote - SSH. Ajouter si nécessaire une entrée locale :

```text
Host ubuntu-devops
    HostName <IP_VM>
    User ubuntu
    IdentityFile ~/.ssh/<cle_privee>
```

Puis ouvrir `ubuntu-devops` avec Remote - SSH. Les outils DevOps restent dans la VM.

## 10. Pools de stockage

```bash
virsh -c qemu:///system pool-list --all
virsh -c qemu:///system pool-info <pool>
virsh -c qemu:///system vol-list <pool>
```

Afficher le chemin d'un volume :

```bash
virsh -c qemu:///system vol-path <volume> --pool <pool>
```

Avant toute suppression, vérifier le domaine qui utilise le volume.

## 11. Disques d'une VM

```bash
virsh -c qemu:///system domblklist ubuntu-devops --details
```

VM arrêtée, inspection QCOW2 :

```bash
qemu-img info /chemin/vers/disque.qcow2
qemu-img check /chemin/vers/disque.qcow2
```

Ne jamais lancer une réparation destructive sur un disque sans backup vérifié.

## 12. XML libvirt

Lecture :

```bash
virsh -c qemu:///system dumpxml ubuntu-devops
virsh -c qemu:///system net-dumpxml devops-nat
```

Exporter avant une modification manuelle :

```bash
virsh -c qemu:///system dumpxml ubuntu-devops > ubuntu-devops.xml
```

Le projet reste la source de vérité ; éviter les modifications manuelles non reproduites dans le dépôt.

## 13. Autostart

Lecture :

```bash
virsh -c qemu:///system dominfo ubuntu-devops | grep -i autostart
virsh -c qemu:///system net-info devops-nat | grep -i autostart
```

**MUTATION :**

```bash
virsh -c qemu:///system autostart ubuntu-devops
virsh -c qemu:///system net-autostart devops-nat
```

Ne l'activer que si cela correspond au comportement souhaité.

## 14. Console

```bash
virsh -c qemu:///system console ubuntu-devops
```

Quitter généralement la console virsh avec `Ctrl+]`.

SSH reste la méthode normale d'administration.

## 15. Création de VM

Pour les VM gérées par ce projet, ne pas improviser une commande `virt-install` manuelle : utiliser l'orchestration et les templates du dépôt afin de conserver cloud-init, réseau, identité, stockage et rollback cohérents.

Avant création :

```bash
./diagnostic.sh
./install.sh --dry-run
```

## 16. Snapshots : prudence

Lister :

```bash
virsh -c qemu:///system snapshot-list ubuntu-devops
```

Les snapshots ne remplacent pas un backup. Éviter d'empiler des snapshots QCOW2 sans stratégie de consolidation. Pour le Disaster Recovery, utiliser le contrat Restic/backup du projet.

## 17. Backup d'une VM

Baseline sûre :

1. arrêt propre de la VM ;
2. vérifier qu'elle est `shut off` ;
3. sauvegarder métadonnées libvirt + QCOW2 via le workflow prévu ;
4. vérifier l'intégrité du backup ;
5. seulement ensuite redémarrer si nécessaire.

Une copie brute d'un QCOW2 actif est interdite.

## 18. Clonage

Un clone doit avoir au minimum une identité libvirt, MAC, cloud-init et réservation DHCP distinctes. Ne pas dupliquer simplement un QCOW2 puis démarrer deux VM avec la même identité.

## 19. Dépannage VM qui ne démarre pas

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domblklist ubuntu-devops --details
virsh -c qemu:///system domiflist ubuntu-devops
virsh -c qemu:///system dumpxml ubuntu-devops
```

Puis contrôler les journaux libvirt/QEMU avec `journalctl` et l'état du pool. Ne supprimer aucune ressource avant d'avoir identifié la cause.

## 20. Dépannage Internet/DNS

Depuis la VM :

```bash
ip route
getent hosts archive.ubuntu.com
ping -c 2 9.9.9.9
ping -c 2 1.1.1.1
```

Depuis le HOST :

```bash
virsh -c qemu:///system net-info devops-nat
virsh -c qemu:///system net-dhcp-leases devops-nat
ip addr show virbr50
```

Ne jamais résoudre un problème en bridgeant la VM vers le LAN physique : cela casserait le contrat d'isolation.

## 21. Commandes utiles dans ubuntu-devops

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
```

Smoke test :

```bash
docker run --rm hello-world
```

## 22. Mémo CLI

```bash
# VM
virsh -c qemu:///system list --all
virsh -c qemu:///system start ubuntu-devops
virsh -c qemu:///system shutdown ubuntu-devops
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops

# Réseau
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-info devops-nat
virsh -c qemu:///system net-dhcp-leases devops-nat

# Stockage
virsh -c qemu:///system pool-list --all
virsh -c qemu:///system vol-list <pool>
virsh -c qemu:///system domblklist ubuntu-devops --details
```

## 23. À retenir

- `virsh -c qemu:///system` est l'interface CLI principale.
- `shutdown` avant `destroy`.
- Ne jamais copier à chaud un QCOW2 actif.
- Ne jamais contourner `devops-nat` par un bridge LAN.
- Un snapshot n'est pas un backup.
- Toujours conserver diagnostic, logs et rapports avant une correction importante.
- Utiliser `RUNBOOK_OPERATIONS.md` pour les procédures d'exploitation et de Disaster Recovery.
