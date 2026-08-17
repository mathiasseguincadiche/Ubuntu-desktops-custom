# Runbook Backup / Restore / Disaster Recovery

Ce document décrit la sauvegarde, la restauration et la reprise après sinistre de la workstation Ubuntu-desktops-custom V1.0.0.

## 1. Principes

- utiliser un dépôt Restic chiffré ;
- stocker la sauvegarde sur une cible externe au filesystem système ;
- vérifier l'intégrité avant de considérer un backup valide ;
- ne jamais copier brutalement un QCOW2 actif ;
- restaurer d'abord en staging ;
- ne jamais supprimer le dernier backup vérifié avant qu'un nouveau backup valide existe.

Une cible locale n'est considérée externe que si son périphérique bloc est exposé comme USB, removable ou hotplug. **Un second SSD interne ne satisfait pas** `BACKUP_REQUIRE_EXTERNAL_TARGET=true`, même s'il possède un filesystem distinct de `/`. Un backend Restic distant constitue également une cible externe valide.

## 2. Backup pré-APPLY

### Workflow canonique automatisé

Après un `FULL_DRY_RUN_PASS` lié au commit courant, utiliser le menu :

```bash
./menu.sh
```

puis :

```text
3) Préparer et vérifier le backup pré-APPLY (Restic)
```

Le menu appelle `./prepare-preapply-backup.sh`. Ce workflow :

1. exige un worktree Git suivi propre et la preuve `FULL_DRY_RUN_PASS` du commit courant ;
2. découvre les filesystems montés sur un périphérique prouvé USB/removable/hotplug ;
3. refuse automatiquement le filesystem racine et les SSD internes ;
4. refuse l'ambiguïté si plusieurs cibles externes sont présentes ;
5. exige par défaut un filesystem EXT4 monté en lecture/écriture et au moins 20 GiB libres ;
6. crée uniquement le sous-répertoire `Backup-Ubuntu/restic` sur la cible retenue ;
7. ne formate, ne repartitionne et ne supprime aucun fichier étranger au dépôt Restic ;
8. initialise le dépôt chiffré lorsqu'il n'existe pas encore, sans écraser un répertoire non vide qui ne serait pas un dépôt Restic ;
9. capture les fichiers système privilégiés sélectionnés (`/etc/fstab`, APT, systemd, `/etc/default`, modprobe, sysctl, udev) dans `system-config.tar` avec ACL, xattrs et propriétaires numériques conservés ; Restic reste exécuté sans privilèges et ne parcourt jamais directement ces fichiers root-only ;
10. capture les fichiers Git suivis, la preuve de dry-run, les backups de migration disponibles et un inventaire machine ;
11. crée un snapshot Restic étiqueté avec le commit et le `RUN_ID` ;
12. exécute un test de restauration granulaire sur un fichier canari ;
13. appelle `verify-preapply-backup.sh`, qui exécute ensuite `restic check --read-data` et écrit la preuve `BACKUP_VERIFIED`.

La capture système privilégiée est volontairement séparée de Restic : `sudo` sert uniquement à lire les fichiers système et à produire l'archive locale de staging. L'archive est ensuite rendue à l'utilisateur courant en mode `0600`. Le dépôt Restic externe ne devient donc pas root-owned.

Le fichier :

```text
state/preapply-backup/<RUN_ID>/system-config.paths.txt
```

liste le contenu capturé et permet d'auditer la présence des chemins système attendus avant le snapshot.

Lors de la première utilisation, le workflow demande une passphrase Restic d'au moins 16 caractères et la stocke par défaut dans :

```text
~/.config/ubuntu-desktops-custom/secrets/restic-password
```

Le fichier est créé avec des permissions privées et n'est jamais stocké dans Git. **La passphrase doit aussi être conservée séparément**, par exemple dans un gestionnaire de mots de passe : perdre simultanément la machine et cette passphrase rendrait le dépôt chiffré inutilisable.

Si exactement une cible externe admissible est montée, elle est sélectionnée automatiquement. En présence de plusieurs cibles, fournir explicitement le point de montage voulu uniquement pour cette exécution :

```bash
BACKUP_TARGET_MOUNT_RUNTIME=/chemin/du/disque/externe ./prepare-preapply-backup.sh
```

Le sous-répertoire du dépôt reste défini par `BACKUP_PREAPPLY_REPOSITORY_SUBDIR=Backup-Ubuntu/restic` dans `config/backup.conf`.

### Vérification avancée d'un dépôt déjà existant

La variable canonique du projet est `BACKUP_REPOSITORY_RUNTIME`; `RESTIC_REPOSITORY` est aussi accepté comme alias standard Restic. Ne pas définir les deux avec des valeurs différentes.

```bash
export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic
export RESTIC_PASSWORD_FILE=/chemin/securise/restic-password
./verify-preapply-backup.sh
```

Alternative équivalente :

```bash
export RESTIC_REPOSITORY=/chemin/externe/restic
export RESTIC_PASSWORD_FILE=/chemin/securise/restic-password
./verify-preapply-backup.sh
```

Pour un dépôt local, le verifier contrôle le filesystem puis remonte la chaîne bloc avec `lsblk`; un NVMe/SATA interne est refusé si aucune propriété USB/removable/hotplug ne prouve le caractère externe. Cette classification est volontairement fail-closed.

La preuve produite doit être liée au commit courant et respecter la fenêtre de fraîcheur configurée.

## 3. Vérification Restic

Exemples de contrôles :

```bash
restic snapshots
restic check --read-data
```

Ne pas considérer la seule présence d'un snapshot comme une preuve d'intégrité suffisante. Un snapshot créé par Restic avec un code retour non nul, par exemple parce qu'un fichier source était illisible, n'est jamais accepté comme `BACKUP_VERIFIED` même si Restic a écrit un identifiant de snapshot.

## 4. Sauvegarde HOST

Sauvegarder prioritairement les éléments nécessaires à la reconstruction : configuration du projet, inventaires, données utilisateur explicitement prévues et configuration reproductible. Une image brute complète du système n'est pas le modèle canonique de reconstruction.

Le snapshot pré-APPLY automatique ne réalise donc pas une image brute du système. Il protège les éléments reproductibles et les preuves nécessaires avant la convergence réelle.

Les fichiers système nécessitant root sont encapsulés dans `system-config.tar`. Cela permet de préserver leur contenu et leurs métadonnées sans exécuter le dépôt Restic lui-même en root.

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

Pour restaurer un fichier système capturé dans `system-config.tar`, restaurer d'abord l'archive depuis Restic dans un staging, lister son contenu, puis extraire uniquement le chemin voulu dans un second staging :

```bash
tar -tf system-config.tar | less
mkdir -p /tmp/udc-system-restore
sudo tar --acls --xattrs --numeric-owner -xpf system-config.tar \
  -C /tmp/udc-system-restore etc/default/cacerts
```

Comparer ensuite le fichier extrait avec la machine active. **Ne jamais extraire directement `system-config.tar` sur `/` sans revue et approbation explicites.**

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
