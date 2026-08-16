# Ubuntu-desktops-custom

Workstation-as-code pour **Ubuntu Desktop 26.04 LTS** : configuration du HOST, virtualisation KVM/libvirt CLI-first, VM Ubuntu Server 26.04 DevOps, VM graphiques optionnelles et sauvegarde/restauration.

Ce README décrit l'architecture et le mode d'utilisation supportés du dépôt. La version publiée est portée par `VERSION` ; l'historique des évolutions appartient à `CHANGELOG.md`.

## Ce que fait le projet

- **HOST** — Ubuntu Desktop 26.04, mises à jour, firmware/microcode AMD, Intel Arc, codecs/multimédia, applications, terminal Bash/Ptyxis, SSH, gaming, observabilité matérielle et validation.
- **KVM** — QEMU/libvirt, `virsh`, OVMF/UEFI, TPM, pools/volumes, catalogue Ubuntu vérifié, réseau NAT custom, SSH, profils de VM graphiques optionnelles et validation.
- **VM_DEVOPS** — Ubuntu Server 26.04 LTS, cloud-init, SSH, Git, Terraform, Ansible, Docker Engine/Buildx/Compose, kubectl, Helm, kind, AWS CLI, Azure CLI et outils DevSecOps.
- **VM GRAPHIQUES OPTIONNELLES** — Ubuntu Desktop 26.04 avec VirtIO-GPU/3D/VirGL/SPICE GL et Windows 11 avec UEFI Secure Boot, TPM 2.0 et VirtIO. Elles ne sont jamais créées automatiquement pendant l'installation initiale.
- **BACKUP/RESTORE** — Restic chiffré, inventaire, intégrité, rétention, restauration granulaire et disaster recovery.

## Sources de vérité

Les paramètres opérationnels ne sont pas dupliqués dans la documentation :

- `config/` — paramètres runtime et gates ;
- `manifests/` — contrats de paquets, outils, modules et systèmes invités ;
- `modules/` — convergence HOST/KVM/VM_DEVOPS/BACKUP ;
- `scripts/` — helpers et opérations spécialisées ;
- `VERSION` — version publiée ;
- `CHANGELOG.md` — historique des évolutions ;
- `docs/` — procédures, architecture et runbooks de référence.

En cas d'écart entre une valeur documentée et une configuration exécutable, les fichiers de configuration/manifeste et les contrôles du dépôt font foi.

## Avant de commencer

Le projet cible une installation Ubuntu Desktop 26.04 LTS native. Lire d'abord `docs/INSTALLATION_GUIDE.md` et `docs/EXECUTION_CONTRACT.md`, puis disposer d'un backup externe vérifié avant toute exécution réelle.

Après clonage :

```bash
git clone https://github.com/mathiasseguincadiche/Ubuntu-desktops-custom.git
cd Ubuntu-desktops-custom
git checkout main
git pull --ff-only
chmod +x menu.sh diagnostic.sh install.sh repair.sh verify-preapply-backup.sh scripts/kvm/vm-profile
```

Identifier la révision avant toute opération :

```bash
cat VERSION
git rev-parse HEAD
```

## Point d'entrée recommandé : menu interactif

```bash
./menu.sh
```

Le menu donne accès aux opérations principales :

```text
1) Diagnostic global GO / NO-GO
2) Dry-run complet HOST -> KVM -> VM_DEVOPS -> BACKUP
3) Installation reelle protegee (--apply)
4) Afficher le plan complet
5) Afficher les gates de securite
6) Lister les VM KVM
7) Lister les profils de VM optionnelles
8) Afficher le chemin du guide de demarrage
0) Quitter
```

L'installation réelle appelle `install.sh --apply` et reste soumise au preflight, au dry-run du commit courant, au backup Restic vérifié et aux confirmations interactives.

## Parcours recommandé

```text
README
  ↓
INSTALLATION_GUIDE
  ↓
EXECUTION_CONTRACT
  ↓
Diagnostic
  ↓
Dry-run complet
  ↓
Backup Restic vérifié
  ↓
Installation réelle protégée
  ↓
Postchecks
```

Les commandes directes restent disponibles :

```bash
./diagnostic.sh
./install.sh --dry-run
./install.sh --apply
```

Ne lancer `--apply` qu'après validation du diagnostic, du dry-run et du backup pré-APPLY.

## Réseau KVM

`devops-nat` utilise `192.168.50.0/24` avec :

- bridge HOST `virbr50` : `192.168.50.254` ;
- DHCP : `192.168.50.100-200` ;
- DNS : `9.9.9.9` et `1.1.1.1` ;
- HOST ↔ VM : autorisé ;
- VM ↔ VM : autorisé ;
- VM → Internet : autorisé ;
- VM → LAN physique : bloqué ;
- LAN → VM : bloqué ;
- Internet → VM : bloqué par défaut.

Voir `docs/NETWORK_KVM_NAT_CUSTOM.md`.

## Catalogue OS KVM

`osinfo-db` fournit les métadonnées invitées à libvirt/virt-install. Le catalogue du projet est défini dans `manifests/virtualization/os-catalog.yml`.

Pendant la convergence KVM réelle, les médias Ubuntu configurés sont résolus contre les `SHA256SUMS` officiels Canonical. La preuve runtime est écrite dans :

```text
state/kvm/os-catalog.resolved
```

Le catalogue n'est considéré prêt que si tous les médias configurés disposent d'un SHA-256 officiel courant.

## VM déployée automatiquement

La VM principale créée par l'installation est `ubuntu-devops` : Ubuntu Server 26.04 LTS sans environnement graphique, dédiée aux outils DevOps/DevSecOps. Les outils DevOps restent dans cette VM et ne sont pas installés sur le HOST.

## Profils KVM optionnels

Les templates canoniques sont définis dans `config/vm-profiles.conf` et consommés par `scripts/kvm/vm-profile`.

```bash
scripts/kvm/vm-profile list
scripts/kvm/vm-profile show ubuntu-desktop
scripts/kvm/vm-profile show windows-11
```

`command` génère une commande `virt-install` révisable sans mutation. `create` crée explicitement la VM après contrôles et confirmation interactive.

Le profil Ubuntu Desktop utilise VirtIO-GPU + accélération 3D + VirGL/OpenGL + SPICE GL et détecte dynamiquement le render node Intel. **Le GPU passthrough/VFIO est interdit par l'architecture du projet** : l'Intel Arc reste propriété du HOST.

Voir `docs/KVM_DESKTOP_VM_PROFILES.md`.

## Sécurité d'exécution

Le chemin d'exécution réelle est **fail-closed** : `REAL_MACHINE_APPROVED=false` reste la valeur statique. `./install.sh --apply` exige notamment un TTY interactif, un preflight réel valide, un dry-run réussi sur le même commit, un backup Restic externe vérifié et récent, une confirmation globale exacte et des confirmations séparées pour HOST, KVM, VM_DEVOPS et BACKUP.

Le contrat complet est documenté dans `docs/EXECUTION_CONTRACT.md` et `docs/SECURITY.md`.

## Validation GitHub

La CI couvre notamment :

- tests unitaires et d'intégration ;
- contrats dry-run ;
- ShellCheck ;
- non-régression ;
- résolution des paquets HOST et KVM sur Ubuntu 26.04 ;
- vérification du catalogue Ubuntu contre les `SHA256SUMS` officiels Canonical ;
- pré-test réel Ubuntu Server 26.04 sous KVM, avec installation de la pile DevOps/DevSecOps, smoke tests Docker et persistance après reboot.

Le statut courant doit être consulté dans GitHub Actions sur le commit à exécuter ; la documentation ne fige pas un numéro de run particulier.

## Documentation

Point d'entrée documentaire : **`docs/DOCUMENTATION_INDEX.md`**.

- `docs/INSTALLATION_GUIDE.md` — installation et première exécution de A à Z ;
- `docs/EXECUTION_CONTRACT.md` — conditions et gates obligatoires avant toute exécution réelle ;
- `docs/RUNBOOK_OPERATIONS.md` — runbook principal : exploitation, maintenance, KVM, VM DevOps, VM graphiques optionnelles, backup, restore, disaster recovery, incidents et rollback ;
- `docs/HOST_RUNBOOK.md` — exploitation du HOST Ubuntu Desktop, matériel, firmware, Intel Arc, desktop et gaming ;
- `docs/GUIDE_DEBUTANT_KVM_LIBVIRT.md` — guide CLI KVM/libvirt pour l'administration quotidienne ;
- `docs/KVM_DESKTOP_VM_PROFILES.md` — templates Ubuntu Desktop/Windows 11, accélération graphique, Secure Boot/TPM et création contrôlée ;
- `docs/NETWORK_KVM_NAT_CUSTOM.md` — contrat et dépannage réseau KVM ;
- `docs/VM_DEVOPS_RUNBOOK.md` — exploitation de la VM Ubuntu Server DevOps et de sa pile DevOps/DevSecOps ;
- `docs/BACKUP_RESTORE_RUNBOOK.md` — sauvegarde Restic, restauration granulaire, QCOW2 et disaster recovery ;
- `docs/TROUBLESHOOTING.md` — dépannage transversal HOST/KVM/réseau/VM/DevOps/backup ;
- `docs/ARCHITECTURE_TECHNIQUE.md` — architecture technique ;
- `docs/HOST_PREFLIGHT_CONTRACT.md` — contrat de preflight HOST ;
- `docs/MODULE_EXECUTION_PLAN.md` — ordre et dépendances des modules ;
- `docs/ORCHESTRATION_ENGINE.md` — fonctionnement du moteur ;
- `docs/SECURITY.md` — règles de sécurité.

Pour l'exploitation quotidienne, utiliser `docs/RUNBOOK_OPERATIONS.md`.
