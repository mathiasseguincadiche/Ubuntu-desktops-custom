# Guide d'installation — Ubuntu-desktops-custom

## Objectif

Converger une installation native Ubuntu Desktop 26.04 LTS vers la workstation définie par ce dépôt, puis construire KVM/libvirt et la VM Ubuntu Server 26.04 DevOps.

Ce guide décrit la procédure supportée par l'état courant de `main`. La version publiée est identifiée par `VERSION` et l'historique des évolutions par `CHANGELOG.md` ; le guide n'est pas une note de version.

## 1. Préconditions

- Ubuntu Desktop 26.04 LTS installé sur le HOST.
- Connexion Internet fonctionnelle.
- `git` installé pour cloner et identifier exactement le commit exécuté.
- Virtualisation AMD-V/SVM activée dans l'UEFI et `/dev/kvm` disponible.
- Filesystem système `/` en EXT4.
- Volume DATA monté sur `/data` en EXT4 conformément à `config/workstation.conf`.
- Dépôt cloné localement.
- Accès `sudo` pour l'opérateur.
- Cible de sauvegarde externe disponible avant l'APPLY réel.
- `restic` disponible pour le workflow de backup pré-APPLY.

Sur une installation Ubuntu fraîche, Git peut être installé avec :

```bash
sudo apt update
sudo apt install -y git
```

Lire également `EXECUTION_CONTRACT.md` avant la première exécution réelle.

## 2. Récupérer la référence à exécuter

```bash
git clone https://github.com/mathiasseguincadiche/Ubuntu-desktops-custom.git
cd Ubuntu-desktops-custom
git checkout main
git pull --ff-only
cat VERSION
git rev-parse HEAD
```

Conserver le SHA du commit utilisé pour le diagnostic, le dry-run, la preuve de backup et l'APPLY. Ces étapes doivent rester liées à la même révision.

Le point d'entrée recommandé est :

```bash
./menu.sh
```

## 3. Diagnostic initial

```bash
./diagnostic.sh
```

Le diagnostic est entièrement en lecture seule. Il combine l'audit des contrats du dépôt avec le preflight du HOST physique : Ubuntu 26.04, virtualisation AMD-V/SVM, EXT4 système/DATA, disponibilité de `/dev/kvm` et inventaire matériel/réseau. Les sondes d'état `virsh`, `systemctl`, `nft` ou équivalentes sont autorisées lorsqu'elles sont strictement non mutantes ; les commandes qui modifient le système doivent rester médiées par les runners sécurisés du projet.

Le diagnostic ajoute aussi un inventaire des applications suivies par `manifests/host/app-packaging-policy.conf` à travers APT/DEB, Snap et Flatpak. Le rapport `reports/<RUN_ID>-app-packaging-inventory.txt` indique la source préférée et la source réellement présente :

- `CONFORMING` : application déjà présente dans la source attendue ;
- `PLANNED` : application absente et prévue par la convergence ;
- `PRESERVED` : application Ubuntu existante conservée dans son format natif ;
- `DRIFT` : application présente via une autre source que celle retenue par le projet ;
- `DUPLICATE` : plusieurs gestionnaires fournissent la même application.

`DRIFT` et `DUPLICATE` sont des avertissements à examiner avant l'APPLY ; l'inventaire ne supprime ni ne migre automatiquement aucune application.

Verdict attendu avant de passer au dry-run :

```text
VERDICT: GO DIAGNOSTIC
NEXT STEP: FULL DRY-RUN
```

Ne pas continuer en présence d'un KO. Les avertissements doivent être compris avant l'APPLY. Le rapport global, l'inventaire HOST et l'inventaire de packaging sont conservés dans `reports/`.

## 4. Dry-run intégral

```bash
./install.sh --dry-run
```

Le dry-run traverse HOST → KVM → VM_DEVOPS → BACKUP sans autoriser de mutation réelle.

Les entrées sensibles ou spécifiques à l'exécution réelle, notamment `VM_ADMIN_USER`, les clés SSH et les paramètres/secrets Restic, ne sont pas requises pour compléter le dry-run. Les modules qui ont besoin d'une identité VM utilisent uniquement des valeurs synthétiques non secrètes et non utilisables en production. En mode `--apply`, ces valeurs synthétiques sont interdites et les entrées runtime réelles restent obligatoires.

Verdict attendu :

```text
VERDICT: FULL DRY-RUN PASS
```

La preuve de dry-run doit correspondre au commit courant et à un worktree Git suivi propre.

## 5. Backup pré-APPLY

Le chemin normal est entièrement piloté par le projet. Depuis :

```bash
./menu.sh
```

sélectionner :

```text
3) Préparer et vérifier le backup pré-APPLY (Restic)
```

Le workflow `prepare-preapply-backup.sh` exige d'abord la preuve de dry-run du commit courant. Il détecte automatiquement une cible locale montée uniquement si son stockage est prouvé USB/removable/hotplug, refuse le filesystem système et les SSD internes, puis utilise par défaut :

```text
<cible-externe>/Backup-Ubuntu/restic
```

Aucun formatage ni repartitionnement n'est effectué. Les autres données déjà présentes sur le disque externe restent hors du dépôt Restic.

Si plusieurs disques externes admissibles sont montés, le workflow bloque au lieu de choisir arbitrairement. L'opérateur peut alors préciser le point de montage pour cette exécution :

```bash
BACKUP_TARGET_MOUNT_RUNTIME=/chemin/du/disque/externe ./prepare-preapply-backup.sh
```

Lors de la première initialisation, une passphrase Restic d'au moins 16 caractères est demandée de manière masquée. Le fichier secret local est créé par défaut dans `~/.config/ubuntu-desktops-custom/secrets/restic-password`, avec des permissions privées. La passphrase doit être conservée séparément pour permettre une restauration après perte de la machine.

Le workflow capture ensuite les fichiers Git suivis, les configurations HOST reproductibles sélectionnées, l'inventaire machine et les sauvegardes de migration disponibles. Il crée un snapshot, exécute un test de restauration granulaire, puis appelle le verifier canonique qui termine par `restic check --read-data` et crée la preuve `BACKUP_VERIFIED`.

Verdict attendu :

```text
PRE-APPLY BACKUP READY
```

Pour l'administration avancée d'un dépôt Restic déjà existant, le verifier peut toujours être appelé directement. La variable canonique du projet pour la cible est `BACKUP_REPOSITORY_RUNTIME`; `RESTIC_REPOSITORY` est accepté comme alias standard Restic :

```bash
export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic
export RESTIC_PASSWORD_FILE=/chemin/securise/restic-password
./verify-preapply-backup.sh
```

Le script refuse des valeurs divergentes si `BACKUP_REPOSITORY_RUNTIME` et `RESTIC_REPOSITORY` sont définies simultanément. Le backup doit contenir au moins un snapshot, passer `restic check --read-data`, être récent et être associé au même commit Git que le dry-run.

## 6. Exécution réelle

Uniquement lorsque diagnostic, dry-run et backup sont propres, revenir dans :

```bash
./menu.sh
```

puis sélectionner :

```text
4) Installation reelle protegee (--apply)
```

Équivalent direct :

```bash
./install.sh --apply
```

L'installateur demande les confirmations interactives prévues par `EXECUTION_CONTRACT.md`.

Ordre de convergence :

1. HOST
2. KVM
3. VM_DEVOPS
4. BACKUP

Pendant la phase KVM, le catalogue OS est résolu à partir des `SHA256SUMS` officiels Canonical. La preuve courante est écrite dans `state/kvm/os-catalog.resolved` et doit contenir `status=verified`.

En cas d'échec, ne pas forcer la phase suivante et conserver les logs/rapports avant toute correction.

## 7. Validation après installation

Relancer les contrôles de base :

```bash
./diagnostic.sh
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
cat state/kvm/os-catalog.resolved
```

Puis valider `ubuntu-devops` et sa pile conformément à `RUNBOOK_OPERATIONS.md` et `VM_DEVOPS_RUNBOOK.md`.

## 8. Réseau attendu

`devops-nat` :

- réseau `192.168.50.0/24` ;
- passerelle HOST `192.168.50.254` ;
- DHCP `192.168.50.100-200` ;
- DNS `9.9.9.9` et `1.1.1.1` ;
- HOST ↔ VM autorisé ;
- VM ↔ VM autorisé ;
- VM → Internet autorisé ;
- VM → LAN physique bloqué ;
- LAN → VM bloqué ;
- Internet → VM bloqué par défaut.

Voir `NETWORK_KVM_NAT_CUSTOM.md` pour le contrat complet.

## 9. Après installation

Utiliser :

- `menu.sh` comme point d'entrée interactif ;
- `RUNBOOK_OPERATIONS.md` pour l'exploitation quotidienne ;
- `HOST_RUNBOOK.md` pour les opérations spécifiques au HOST ;
- `VM_DEVOPS_RUNBOOK.md` pour la VM DevOps ;
- `BACKUP_RESTORE_RUNBOOK.md` pour sauvegarde, restauration et disaster recovery ;
- `TROUBLESHOOTING.md` pour le diagnostic d'incident.
