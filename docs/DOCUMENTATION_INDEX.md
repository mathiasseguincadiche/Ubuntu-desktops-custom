# Index documentation — Ubuntu-desktops-custom

Cet index indique quel document utiliser selon l'opération à réaliser.

## Installation et première mise en service

1. `INSTALLATION_GUIDE.md` — procédure canonique depuis Ubuntu Desktop 26.04 LTS propre jusqu'à l'APPLY protégé.
2. `HOST_PREFLIGHT_CONTRACT.md` — conditions que le HOST doit respecter.
3. `HOST_RUNBOOK.md` — exploitation du HOST physique, matériel, firmware, Intel Arc, desktop, terminal et gaming.
4. `MODULE_EXECUTION_PLAN.md` — ordre HOST → KVM → VM_DEVOPS → BACKUP.
5. `GUIDE_DEBUTANT_KVM_LIBVIRT.md` — administration KVM/libvirt CLI-first.
6. `NETWORK_KVM_NAT_CUSTOM.md` — réseau NAT custom et isolation LAN.
7. `KVM_DESKTOP_VM_PROFILES.md` — profils optionnels Ubuntu Desktop et Windows 11, affichage accéléré et cycle de création.
8. `VM_DEVOPS_RUNBOOK.md` — exploitation de `ubuntu-devops` et de la pile DevOps/DevSecOps.
9. `BACKUP_RESTORE_RUNBOOK.md` — sauvegarde, restauration et Disaster Recovery.

## Exploitation quotidienne

- `RUNBOOK_OPERATIONS.md` — runbook principal : contrôle quotidien, maintenance, KVM, VM DevOps, réseau, backup, restauration, incidents et rollback.
- `HOST_RUNBOOK.md` — opérations spécifiques au HOST Ubuntu Desktop.
- `KVM_DESKTOP_VM_PROFILES.md` — référence des VM graphiques optionnelles.
- `VM_DEVOPS_RUNBOOK.md` — opérations spécifiques à la VM DevOps.
- `BACKUP_RESTORE_RUNBOOK.md` — procédures Restic, QCOW2 et reconstruction.
- `TROUBLESHOOTING.md` — diagnostic transversal HOST/KVM/réseau/VM/DevOps/backup.

## Architecture et fonctionnement interne

- `ARCHITECTURE_TECHNIQUE.md` — architecture générale et séparation des responsabilités.
- `ORCHESTRATION_ENGINE.md` — moteur, phases, états, reprise et exécution.
- `NETWORK_KVM_NAT_CUSTOM.md` — contrat `devops-nat`, isolation LAN et diagnostic réseau.
- `KVM_DESKTOP_VM_PROFILES.md` — contrats de ressources, UEFI/TPM/VirtIO et accélération graphique des VM Desktop.
- `SECURITY.md` — règles de sécurité et principes fail-closed.
- `MODULE_EXECUTION_PLAN.md` — dépendances entre modules.

## Sauvegarde et reprise après sinistre

Document canonique détaillé : `BACKUP_RESTORE_RUNBOOK.md`.

Le `RUNBOOK_OPERATIONS.md` conserve la synthèse opérationnelle et l'ordre de Disaster Recovery complet.

## Validation

GitHub Actions couvre les tests unitaires, intégration, dry-run, ShellCheck, non-régression et le laboratoire Ubuntu Server 26.04 KVM réel.

## Parcours recommandé

Première utilisation :

```text
README.md
   ↓
INSTALLATION_GUIDE.md
   ↓
HOST_RUNBOOK.md
   ↓
GUIDE_DEBUTANT_KVM_LIBVIRT.md
   ↓
KVM_DESKTOP_VM_PROFILES.md
   ↓
VM_DEVOPS_RUNBOOK.md
   ↓
BACKUP_RESTORE_RUNBOOK.md
```

Incident :

```text
RUNBOOK_OPERATIONS.md
   ↓
TROUBLESHOOTING.md
   ↓
document spécialisé concerné
```

Reconstruction complète :

```text
BACKUP_RESTORE_RUNBOOK.md
   ↓
INSTALLATION_GUIDE.md
   ↓
validation HOST / KVM / VM_DEVOPS
```
