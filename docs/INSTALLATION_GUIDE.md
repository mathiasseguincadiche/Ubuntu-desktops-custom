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

Verdict attendu avant de passer au dry-run :

```text
VERDICT: GO DIAGNOSTIC
NEXT STEP: FULL DRY-RUN
```

Ne pas continuer en présence d'un KO. Les avertissements doivent être compris avant l'APPLY. Le rapport global et l'inventaire HOST sont conservés dans `reports/`.

## 4. Dry-run intégral

```bash
./install.sh --dry-run
```

Le dry-run traverse HOST → KVM → VM_DEVOPS → BACKUP sans autoriser de mutation réelle.

Verdict attendu :

```text
VERDICT: FULL DRY-RUN PASS
```

La preuve de dry-run doit correspondre au commit courant.

## 5. Backup pré-APPLY

Configurer le dépôt Restic externe et ses secrets uniquement au runtime, puis exécuter :

```bash
./verify-preapply-backup.sh
```

Le backup doit être vérifié, récent et associé au même commit Git que le dry-run.

## 6. Exécution réelle

Uniquement lorsque diagnostic, dry-run et backup sont propres :

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
