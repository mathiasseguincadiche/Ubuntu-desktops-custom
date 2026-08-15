# Runbook Backup / Restore / Disaster Recovery

Ce document décrit la sauvegarde, la restauration et la reprise après sinistre de la workstation Ubuntu-desktops-custom V1.0.0.

## 1. Principes

- utiliser un dépôt Restic chiffré ;
- stocker la sauvegarde sur une cible externe au filesystem système ;
- vérifier l'intégrité avant de considérer un backup valide ;
- ne jamais copier brutalement un QCOW2 actif ;
- restaurer d'abord en staging ;
- ne jamais supprimer le dernier backup vérifié avant qu'un nouveau backup valide existe.

## 2. Backup pré-APPLY

Fournir les secrets uniquement au runtime :

```bash
export RESTIC_REPOSITORY=/chemin/externe/restic
export RESTIC_PASSWORD_FILE=/chemin/securise/restic-password
./verify-preapply-backup.sh
```

La preuve produite doit être liée au commit courant et respecter la fenêtre de fraîcheur configurée.

## 3. Vérification Restic

Exemples de contrôles :

```bash
restic snapshots
restic check --read-data
```

Ne pas considérer la seule présence d'un snapshot comme une preuve d'intégrité suffisante.

## 4. Sauvegarde HOST

Sauvegarder prioritairement les éléments nécessaires à la reconstruction : configuration du projet, inventaires, données utilisateur explicitement prévues et configuration reproductible. Une image brute complète du système n'est pas le modèle canonique de reconstruction.

## 5. Sauvegarde KVM/libvirt

Conserver :

- XML des domaines ;
- définition `devops-nat` ;
- pools et volumes ;
- identité déterministe des VM ;
- informations UEFI/NVRAM/TPM lorsqu'applicables.

Contrôles :

```bash
virsh -c qemu:///system dumpxml ubuntu-devops
virsh -c qemu:///system net-dumpxml devops-nat
virsh -c qemu:///system pool-list --all
```

## 6. Sauvegarde de ubuntu-devops

Baseline recommandée : arrêt propre de la VM avant sauvegarde complète du QCOW2.

```bash
virsh -c qemu:///system shutdown ubuntu-devops
virsh -c qemu:///system domstate ubuntu-devops
```

Attendre l'état `shut off` avant une sauvegarde fichier classique. Les workflows online avancés exigent une procédure dédiée testée avec guest-agent/quiesce/snapshot.

## 7. Rétention

Baseline projet :

- 7 sauvegardes quotidiennes ;
- 4 hebdomadaires ;
- 6 mensuelles.

La rétention/prune est destructive : vérifier un snapshot récent avant toute suppression.

## 8. Restauration granulaire

1. Lister les snapshots.
2. Sélectionner le point de restauration.
3. Restaurer dans un répertoire de staging.
4. Vérifier contenu, permissions, ownership et intégrité.
5. Comparer avec les données actuelles.
6. Promouvoir explicitement seulement après validation.

Ne jamais écraser directement les données live par défaut.

## 9. Restauration VM

Avant premier boot :

```bash
qemu-img check /chemin/ubuntu-devops.qcow2
```

Restaurer ensuite XML, réseau/pool et identité de la VM. Revalider `devops-nat` et l'isolation LAN avant de démarrer le guest.

## 10. Disaster Recovery complet

Ordre canonique :

1. clean-install Ubuntu Desktop 26.04 LTS ;
2. restaurer/cloner Ubuntu-desktops-custom ;
3. revalider HOST ;
4. reconstruire QEMU/KVM/libvirt ;
5. restaurer pools et `devops-nat` ;
6. vérifier l'isolation LAN ;
7. restaurer XML et QCOW2 ;
8. exécuter `qemu-img check` ;
9. démarrer `ubuntu-devops` ;
10. revalider SSH, Internet et DNS ;
11. revalider Docker, Kubernetes, IaC, Cloud CLIs et DevSecOps ;
12. produire le verdict final seulement après validation de bout en bout.

## 11. Critères de réussite

Le backup/restore n'est READY que si :

```text
Repository encryption       PASS
Repository integrity        PASS
Snapshot available          PASS
VM consistency              PASS
Granular restore test       PASS
Network isolation restore   PASS
VM boot                     PASS
DevOps smoke tests          PASS
```

## 12. Incident

En cas de backup ou restore en échec : ne pas lancer de prune, conserver les logs, ne pas détruire les données sources et corriger d'abord la cause avant une nouvelle tentative.
