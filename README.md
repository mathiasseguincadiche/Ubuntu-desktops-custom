# Ubuntu-desktops-custom

Workstation-as-code pour **Ubuntu Desktop 26.04 LTS** : configuration HOST, virtualisation KVM/libvirt CLI-first, VM Ubuntu Server 26.04 DevOps, VM graphiques optionnelles et sauvegarde/restauration.

Version actuelle : **1.0.0**

## Ce que fait le projet

- **HOST** — Ubuntu Desktop 26.04, mises à jour, firmware/microcode AMD, Intel Arc, codecs/multimédia, applications, terminal Bash/Ptyxis, SSH, gaming, observabilité matérielle et validation.
- **KVM** — QEMU/libvirt, `virsh`, OVMF/UEFI, TPM, pools/volumes, catalogue Ubuntu vérifié, réseau NAT custom, SSH, profils de VM graphiques optionnelles et validation.
- **VM_DEVOPS** — Ubuntu Server 26.04 LTS, cloud-init, SSH, Git, Terraform, Ansible, Docker Engine/Buildx/Compose, kubectl, Helm, kind, AWS CLI, Azure CLI et DevSecOps.
- **VM GRAPHIQUES OPTIONNELLES** — Ubuntu Desktop 26.04 avec VirtIO-GPU/3D/VirGL/SPICE GL et Windows 11 avec UEFI Secure Boot, TPM 2.0 et VirtIO. Elles ne sont jamais créées automatiquement pendant l'installation initiale.
- **BACKUP/RESTORE** — Restic chiffré, inventaire, intégrité, rétention, restauration granulaire et disaster recovery.

## Avant de commencer

Le projet cible une installation Ubuntu Desktop 26.04 LTS native. Lire d'abord `docs/INSTALLATION_GUIDE.md` et conserver un backup externe vérifié avant toute exécution réelle.

Après clonage :

```bash
git clone https://github.com/mathiasseguincadiche/Ubuntu-desktops-custom.git
cd Ubuntu-desktops-custom
chmod +x menu.sh diagnostic.sh install.sh repair.sh verify-preapply-backup.sh scripts/kvm/vm-profile
```

## Point d'entrée recommandé : menu interactif

Le moyen le plus simple d'utiliser le projet est :

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

L'option d'installation réelle ne contourne aucune sécurité : elle appelle le même `install.sh --apply` et reste soumise au preflight, au dry-run du commit courant, au backup Restic vérifié et aux confirmations interactives.

## Parcours recommandé

Pour une première installation :

```text
README
  ↓
INSTALLATION_GUIDE
  ↓
./menu.sh
  ↓
Diagnostic
  ↓
Dry-run complet
  ↓
Backup Restic vérifié
  ↓
Installation réelle protégée
  ↓
Postchecks / reboot si nécessaire
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

Le chemin d'exécution réelle reste **fail-closed** : `REAL_MACHINE_APPROVED=false` est la valeur statique par défaut. `./install.sh --apply` exige notamment un TTY interactif, un diagnostic réel valide, un dry-run réussi sur le même commit, un backup Restic externe vérifié et récent, une confirmation globale exacte et des confirmations séparées pour HOST, KVM, VM_DEVOPS et BACKUP.

## Validation GitHub

La base a passé :

- tests unitaires ;
- tests d'intégration ;
- contrats dry-run ;
- ShellCheck ;
- non-régression ;
- pré-test réel Ubuntu Server 26.04 sous KVM, incluant installation de la pile DevOps/DevSecOps, smoke tests Docker et persistance après reboot.

Dernier verdict de référence du laboratoire VM : `REAL UBUNTU 26.04 VM PRE-TEST PASS`.

## Documentation

Point d'entrée documentaire : **`docs/DOCUMENTATION_INDEX.md`**.

- `docs/INSTALLATION_GUIDE.md` — installation et première exécution de A à Z ;
- `docs/RUNBOOK_OPERATIONS.md` — **runbook principal** : exploitation, maintenance, KVM, VM DevOps, VM graphiques optionnelles, backup, restore, disaster recovery, incidents et rollback ;
- `docs/HOST_RUNBOOK.md` — exploitation du HOST Ubuntu Desktop, matériel, firmware, Intel Arc, desktop et gaming ;
- `docs/GUIDE_DEBUTANT_KVM_LIBVIRT.md` — guide CLI KVM/libvirt pour l'administration quotidienne ;
- `docs/KVM_DESKTOP_VM_PROFILES.md` — templates Ubuntu Desktop/Windows 11, accélération graphique, Secure Boot/TPM et création contrôlée ;
- `docs/NETWORK_KVM_NAT_CUSTOM.md` — contrat et dépannage réseau KVM ;
- `docs/VM_DEVOPS_RUNBOOK.md` — exploitation de la VM Ubuntu Server DevOps et de sa pile DevOps/DevSecOps ;
- `docs/BACKUP_RESTORE_RUNBOOK.md` — sauvegarde Restic, restauration granulaire, QCOW2 et disaster recovery ;
- `docs/TROUBLESHOOTING.md` — dépannage transversal HOST/KVM/réseau/VM/DevOps/backup ;
- `docs/ARCHITECTURE_TECHNIQUE.md` — architecture technique ;
- `docs/HOST_PREFLIGHT_CONTRACT.md` — contrat de préflight HOST ;
- `docs/MODULE_EXECUTION_PLAN.md` — ordre et dépendances des modules ;
- `docs/ORCHESTRATION_ENGINE.md` — fonctionnement du moteur ;
- `docs/SECURITY.md` — règles de sécurité.

Pour l'exploitation quotidienne, utiliser `docs/RUNBOOK_OPERATIONS.md`.
