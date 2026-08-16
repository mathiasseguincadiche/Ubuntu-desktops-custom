# Contrat d'exécution réelle — Ubuntu-desktops-custom

Ce document définit les conditions obligatoires avant toute mutation de la workstation physique.

## État par défaut

- `REAL_APPLY_FEATURE_ENABLED=true` rend le chemin protégé disponible ;
- `REAL_MACHINE_APPROVED=false` reste la configuration statique ;
- `DRY_RUN=true` est le comportement de validation avant APPLY ;
- cloner le dépôt, lancer le menu ou exécuter le diagnostic ne donne aucune autorisation de mutation.

## Séquence obligatoire

1. Utiliser le commit exact prévu pour l'installation.
2. Exécuter `./diagnostic.sh` et obtenir un résultat sans KO.
3. Exécuter `./install.sh --dry-run` et obtenir `FULL DRY-RUN PASS`.
4. Préparer un dépôt Restic externe et le fichier de mot de passe runtime.
5. Exécuter `./verify-preapply-backup.sh` avec les variables Restic requises.
6. Obtenir une preuve `BACKUP_VERIFIED` récente et liée au même commit Git.
7. Lancer `./install.sh --apply` uniquement dans un TTY interactif.
8. Passer le preflight HOST réel en lecture seule.
9. Saisir exactement la phrase de confirmation globale demandée.
10. Confirmer séparément les domaines `HOST`, `KVM`, `VM_DEVOPS` et `BACKUP`.
11. Arrêter immédiatement l'exécution en cas d'échec PRECHECK/APPLY/POSTCHECK/ROLLBACK ; aucun contournement de gate n'est autorisé.

## Propriétés de sécurité

- les mutations déclarées passent par `run_mutating` ;
- l'autorisation `REAL_MACHINE_APPROVED=true` n'existe que dans le processus APPLY après validation des gates ;
- le dry-run et la preuve de backup sont liés au commit courant ;
- la preuve de backup expire selon la fenêtre configurée ;
- le dépôt Restic local ne peut pas se trouver sur le même filesystem que `/` ;
- l'intégrité Restic est vérifiée avant génération de la preuve ;
- le réseau `devops-nat` existant est contrôlé avant mutation ;
- les règles firewall du projet restent limitées à leur propre table nftables ;
- aucun flush global nftables/iptables n'est autorisé ;
- le provisioning VM possède un rollback ciblé pour les ressources créées pendant une tentative ;
- les outils DevOps sont installés dans `ubuntu-devops`, jamais sur le HOST pour contourner le contrat ;
- chaque grand domaine nécessite une confirmation indépendante.

## Limite du pré-test CI

La CI et le laboratoire KVM valident le code, les contrats, les paquets Ubuntu 26.04, le catalogue OS officiel et la VM Ubuntu Server 26.04 réelle. Ils ne remplacent pas le preflight sur le matériel physique : GPU Intel Arc, stockage NVMe, firmware/UEFI, écran, interfaces réseau et état réel du HOST doivent encore passer les contrôles locaux avant APPLY.
