# Guide débutant KVM/libvirt

Statut : structure initiale — sera complétée avant la phase d'utilisation réelle.

## Réseau du projet

Les exemples du guide utiliseront le réseau `devops-nat` (`192.168.50.0/24`) et la VM `ubuntu-devops`.

La passerelle `192.168.50.254` appartient à l'interface virtuelle de l'hôte. Les VM reçoivent leurs adresses via DHCP ; les VM importantes utilisent une réservation DHCP déterministe.

## Commandes réseau de base

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-info devops-nat
virsh --connect qemu:///system net-dumpxml devops-nat
```

Ces commandes sont de consultation. Le guide distinguera explicitement les commandes de lecture, de modification et les commandes potentiellement destructrices.

## Plan du guide

1. Comprendre KVM/QEMU/libvirt
2. `qemu:///system`
3. Lister les VM
4. Démarrer/arrêter
5. IP et réseau `devops-nat`
6. SSH et VS Code Remote
7. Pools et volumes
8. Création de VM
9. Snapshots et clones
10. Sauvegarde/restauration
11. Dépannage
12. Mémo CLI
