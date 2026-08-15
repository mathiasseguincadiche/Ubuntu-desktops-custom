# Guide d'installation — Ubuntu-desktops-custom V1.0.0

## Objectif

Converger une installation native Ubuntu Desktop 26.04 LTS vers la workstation définie par ce dépôt, puis construire KVM/libvirt et la VM Ubuntu Server 26.04 DevOps.

## 1. Préconditions

- Ubuntu Desktop 26.04 LTS installé sur le HOST.
- Connexion Internet fonctionnelle.
- Virtualisation AMD-V/SVM activée dans l'UEFI.
- Dépôt cloné localement.
- Accès `sudo` pour l'opérateur.
- Cible de sauvegarde externe disponible avant l'APPLY réel.

## 2. Récupérer la version officielle

```bash
git clone https://github.com/mathiasseguincadiche/Ubuntu-desktops-custom.git
cd Ubuntu-desktops-custom
git checkout main
git pull --ff-only
cat VERSION
```

La version attendue pour ce guide est `1.0.0`.

## 3. Diagnostic initial

```bash
./diagnostic.sh
```

Ne pas continuer en présence d'un KO. Les avertissements doivent être compris avant l'APPLY.

## 4. Dry-run intégral

```bash
./install.sh --dry-run
```

Le dry-run traverse HOST → KVM → VM_DEVOPS → BACKUP sans autoriser de mutation réelle.

Verdict attendu :

```text
VERDICT: FULL DRY-RUN PASS
```

## 5. Backup pré-APPLY

Configurer le dépôt Restic externe et ses secrets uniquement au runtime, puis exécuter :

```bash
./verify-preapply-backup.sh
```

Le backup doit être vérifié, récent et associé au commit courant.

## 6. Exécution réelle

Uniquement lorsque diagnostic, dry-run et backup sont propres :

```bash
./install.sh --apply
```

L'installateur demande des confirmations interactives. Lire chaque phase avant de confirmer.

Ordre :

1. HOST
2. KVM
3. VM_DEVOPS
4. BACKUP

En cas d'échec, ne pas forcer la phase suivante.

## 7. Validation après installation

Relancer :

```bash
./diagnostic.sh
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
```

Puis valider `ubuntu-devops` et sa pile conformément à `RUNBOOK_OPERATIONS.md`.

## 8. Réseau attendu

`devops-nat` :

- réseau `192.168.50.0/24` ;
- passerelle HOST `192.168.50.254` ;
- DHCP `192.168.50.100-200` ;
- DNS `9.9.9.9` et `1.1.1.1` ;
- Internet VM autorisé ;
- accès au LAN physique bloqué.

## 9. Après installation

Utiliser `menu.sh` comme point d'entrée interactif et `RUNBOOK_OPERATIONS.md` pour l'exploitation quotidienne, KVM, sauvegarde, restauration et incidents.
