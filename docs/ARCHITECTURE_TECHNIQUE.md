# Architecture technique

Statut : squelette V1 en revue.

## Domaines stricts

1. HOST — Ubuntu Desktop, matériel, applications, gaming.
2. KVM — QEMU/libvirt, réseaux, pools, firmware et VM.
3. VM_DEVOPS — Ubuntu Server et pile DevOps.
4. BACKUP — sauvegarde, vérification, restauration et disaster recovery.

## Réseau KVM officiel

Toutes les VM gérées par le projet utilisent par défaut le réseau libvirt `devops-nat` :

- `192.168.50.0/24`
- passerelle/interface HOST : `192.168.50.254`
- DHCP : `192.168.50.100-200`
- DNS : `9.9.9.9`, `1.1.1.1`
- HOST ↔ VM : autorisé
- VM ↔ VM : autorisé
- VM → Internet : autorisé par NAT
- VM → LAN physique : bloqué explicitement
- LAN/Internet → VM : bloqué par défaut
- aucun port-forward entrant par défaut

Le NAT seul n'est pas une preuve d'isolation du LAN. L'implémentation devra appliquer puis tester une politique de filtrage dédiée sans écraser le firewall existant. Le PRECHECK inventorie dynamiquement les routes du HOST ; tout chevauchement ou ambiguïté avec `192.168.50.0/24` bloque l'application et demande une revue manuelle.

## VM DevOps

`ubuntu-devops` est attachée explicitement à `devops-nat`. Son adresse stable sera fournie par une réservation DHCP libvirt liée à une identité MAC déterministe ; aucune adresse n'est inventée tant que l'implémentation n'a pas validé les conflits.

## Gate

`REAL_MACHINE_APPROVED=false` reste obligatoire pendant la phase architecture/pré-test. Aucun module ne doit appliquer ce réseau sur la workstation avant validation complète.
