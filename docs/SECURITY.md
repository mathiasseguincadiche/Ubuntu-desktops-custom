# Sécurité

## Principes

- Aucun secret, mot de passe, token ou clé privée dans Git.
- Aucun `curl | bash` et aucun `apt-key`.
- Les dépôts tiers utilisent des keyrings dédiés et les téléchargements sensibles sont vérifiés par checksum/signature lorsque l'upstream le permet.
- Les mutations orchestrées passent par `run_mutating` et restent bloquées en dry-run.
- Aucun flush global nftables/iptables n'est autorisé.
- Aucun GPU passthrough/VFIO n'est autorisé ; l'Intel Arc reste propriété du HOST.

## Gate d'exécution réelle

`REAL_MACHINE_APPROVED=false` est la valeur statique permanente dans la configuration du dépôt.

`REAL_MACHINE_APPROVED=true` n'est exporté que dans le processus `install.sh --apply`, après validation de toutes les conditions suivantes :

1. TTY interactif ;
2. preflight HOST réel réussi ;
3. dry-run intégral réussi sur le commit courant ;
4. backup Restic externe vérifié et suffisamment récent ;
5. confirmation globale exacte ;
6. confirmations indépendantes pour HOST, KVM, VM_DEVOPS et BACKUP.

L'autorisation disparaît avec le processus et n'est jamais persistée dans la configuration.

Voir `EXECUTION_CONTRACT.md` pour la procédure complète.

## Virtualisation et réseau

- libvirt utilise `qemu:///system` comme source de vérité.
- `devops-nat` est fail-closed et ne doit pas être remplacé par un bridge vers le LAN physique.
- HOST ↔ VM, VM ↔ VM et VM → Internet sont autorisés.
- VM → LAN physique, LAN → VM et Internet → VM sont bloqués.
- Le projet ne modifie que sa table nftables dédiée et préserve le firewall global du HOST.
- Un chevauchement de routes ou une ambiguïté réseau bloque la convergence.

## VM et médias

- Les images Ubuntu utilisées par le projet proviennent des sources Canonical configurées.
- Le catalogue runtime vérifie les médias contre les `SHA256SUMS` officiels Canonical.
- L'image cloud de `ubuntu-devops` est authentifiée par signature GPG et SHA-256 avant utilisation.
- Windows 11 utilise UEFI Secure Boot avec clés enrôlées et TPM 2.0 ; aucun bypass n'est prévu.
- La création contrôlée de VM refuse les domaines/volumes homonymes existants et limite le rollback aux ressources créées pendant la tentative.

## Sauvegarde et restauration

- Le backup pré-APPLY doit être externe au filesystem système.
- La preuve Restic est liée au commit courant et soumise à une fenêtre de fraîcheur.
- `restic check --read-data` est exigé avant la preuve de backup.
- Une copie brute à chaud d'un QCOW2 actif est interdite.
- Les restaurations sont effectuées vers une zone de staging avant promotion vers les chemins réels.

## Réponse à incident

En cas d'échec de PRECHECK/APPLY/POSTCHECK/ROLLBACK : arrêter la phase, conserver les logs/rapports/états et suivre `RUNBOOK_OPERATIONS.md` puis `TROUBLESHOOTING.md`. Aucun contournement manuel d'une gate de sécurité n'est considéré comme une correction valide.
