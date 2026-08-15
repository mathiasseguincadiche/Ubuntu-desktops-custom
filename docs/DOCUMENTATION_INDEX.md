# Index documentation — Ubuntu-desktops-custom V1.0.0

Cet index indique quel document utiliser selon l'opération à réaliser.

## Installation et première mise en service

1. `INSTALLATION_GUIDE.md` — procédure canonique depuis Ubuntu Desktop 26.04 LTS propre jusqu'à l'APPLY protégé.
2. `HOST_PREFLIGHT_CONTRACT.md` — conditions que le HOST doit respecter.
3. `MODULE_EXECUTION_PLAN.md` — ordre HOST → KVM → VM_DEVOPS → BACKUP.

## Exploitation quotidienne

- `RUNBOOK_OPERATIONS.md` — **runbook principal** : contrôle quotidien, maintenance, KVM, VM DevOps, réseau, backup, restauration, Disaster Recovery, incidents et rollback.
- `GUIDE_DEBUTANT_KVM_LIBVIRT.md` — administration KVM/libvirt CLI-first avec commandes de base et procédures de dépannage.

## Architecture et fonctionnement interne

- `ARCHITECTURE_TECHNIQUE.md` — architecture générale et séparation des responsabilités.
- `ORCHESTRATION_ENGINE.md` — moteur, phases, états, reprise et exécution.
- `NETWORK_KVM_NAT_CUSTOM.md` — contrat `devops-nat`, isolation LAN et diagnostic réseau.
- `SECURITY.md` — règles de sécurité et principes fail-closed.

## Sauvegarde et reprise après sinistre

Le chapitre canonique d'exploitation est dans `RUNBOOK_OPERATIONS.md` :

- Backup pré-APPLY ;
- sauvegarde cohérente des VM ;
- restauration granulaire via staging ;
- vérification QCOW2 ;
- reconstruction complète Ubuntu/KVM/VM ;
- validation réseau avant redémarrage des guests ;
- revalidation de la pile DevOps/DevSecOps.

## Validation de la release

- `V1_EXECUTION_CANDIDATE.md` — historique de la gate d'exécution ayant précédé la V1.0.0.
- GitHub Actions — tests unitaires, intégration, dry-run, ShellCheck, non-régression et laboratoire Ubuntu Server 26.04 KVM réel.

## Parcours recommandé

Pour une première utilisation :

```text
README.md
   ↓
INSTALLATION_GUIDE.md
   ↓
RUNBOOK_OPERATIONS.md
   ↓
GUIDE_DEBUTANT_KVM_LIBVIRT.md
```

Pour un incident :

```text
RUNBOOK_OPERATIONS.md
   ↓
section incident concernée
   ↓
NETWORK_KVM_NAT_CUSTOM.md ou GUIDE_DEBUTANT_KVM_LIBVIRT.md si nécessaire
```

Pour une reconstruction complète :

```text
RUNBOOK_OPERATIONS.md
   ↓
Disaster Recovery complet
   ↓
INSTALLATION_GUIDE.md
   ↓
validation HOST / KVM / VM_DEVOPS
```
