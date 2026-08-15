# Runbook d'exploitation — Ubuntu-desktops-custom V1.0.0

Ce document est le point d'entrée opérationnel pour administrer, diagnostiquer, maintenir, sauvegarder et restaurer la workstation Ubuntu 26.04 LTS et son environnement KVM/VM DevOps.

## 1. Règles d'or

1. Ne jamais lancer `./install.sh --apply` avant un diagnostic et un dry-run propres sur le même commit.
2. Ne jamais contourner `REAL_MACHINE_APPROVED`, `run_mutating` ou les confirmations de phase.
3. Ne jamais copier à chaud un disque QCOW2 actif.
4. Ne jamais désactiver l'isolation `devops-nat` pour résoudre un problème de connectivité.
5. Avant une opération destructive, disposer d'un backup Restic externe vérifié et récent.

## 2. Contrôle quotidien

Depuis la racine du dépôt :

```bash
git status --short
git rev-parse HEAD
./diagnostic.sh
```

Le diagnostic doit finir sans KO. Les rapports sont conservés dans `reports/`, les logs dans `logs/` et les états dans `state/`.

## 3. Mise à jour / convergence de la workstation

Toujours commencer par :

```bash
git pull --ff-only
./diagnostic.sh
./install.sh --dry-run
```

Si le diagnostic et le dry-run sont propres, vérifier le backup pré-APPLY puis seulement utiliser :

```bash
./install.sh --apply
```

L'APPLY demande des confirmations interactives globales et par domaine. En cas de doute, répondre non et arrêter.

## 4. KVM/libvirt — exploitation CLI

Connexion système :

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
```

Démarrer/arrêter proprement une VM :

```bash
virsh -c qemu:///system start ubuntu-devops
virsh -c qemu:///system shutdown ubuntu-devops
```

Forcer l'arrêt n'est qu'un dernier recours :

```bash
virsh -c qemu:///system destroy ubuntu-devops
```

Afficher l'identité et les interfaces :

```bash
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domiflist ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
```

Voir aussi `GUIDE_DEBUTANT_KVM_LIBVIRT.md`.

## 5. Réseau devops-nat

Contrôles :

```bash
virsh -c qemu:///system net-info devops-nat
virsh -c qemu:///system net-dumpxml devops-nat
ip addr show virbr50
```

Contrat attendu :

- HOST → VM : PASS
- VM → HOST : PASS
- VM → VM : PASS
- VM → Internet : PASS
- DNS 9.9.9.9 / 1.1.1.1 : PASS
- VM → LAN physique : BLOCKED
- LAN → VM : BLOCKED
- Internet → VM : BLOCKED

Ne pas remplacer ce réseau par un bridge vers le LAN physique. Voir `NETWORK_KVM_NAT_CUSTOM.md`.

## 6. VM ubuntu-devops

Après démarrage :

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
```

Connexion SSH avec l'identité prévue par le projet :

```bash
ssh ubuntu@<IP_VM>
```

Contrôles dans la VM :

```bash
git --version
terraform version
ansible --version
docker version
docker compose version
kubectl version --client
helm version
kind version
aws --version
az version
gitleaks version
trivy --version
shellcheck --version
hadolint --version
checkov --version
```

Smoke test Docker :

```bash
docker run --rm hello-world
```

Les outils DevOps doivent rester dans la VM, pas sur le HOST.

## 7. VS Code Remote SSH

Depuis le HOST, utiliser l'extension Remote - SSH de VS Code et la même identité SSH que celle validée pour `ubuntu-devops`. Le développement DevOps se fait dans le filesystem Linux de la VM.

## 8. Backup

Le dépôt Restic doit être externe au filesystem système et chiffré. Avant un APPLY réel :

```bash
./verify-preapply-backup.sh
```

La preuve doit correspondre au commit courant et respecter la fenêtre de fraîcheur configurée.

Pour une VM complète, privilégier un arrêt propre avant sauvegarde du QCOW2. Une copie brute d'un QCOW2 actif est interdite par le contrat.

## 9. Restauration granulaire

1. Identifier le snapshot Restic voulu.
2. Restaurer d'abord vers un répertoire de staging.
3. Vérifier contenu, permissions et intégrité.
4. Ne promouvoir vers les chemins réels qu'après validation.
5. Conserver les données actuelles jusqu'à validation de la restauration.

Ne jamais restaurer directement par-dessus des données de production sans staging.

## 10. Disaster Recovery complet

Ordre canonique :

1. Réinstaller proprement Ubuntu Desktop 26.04 LTS.
2. Restaurer le dépôt/projet et la configuration nécessaires.
3. Exécuter diagnostic et convergence HOST.
4. Reconstruire QEMU/KVM/libvirt et les pools de stockage.
5. Restaurer `devops-nat` et valider l'isolation LAN avant tout boot VM.
6. Restaurer les métadonnées libvirt et les QCOW2.
7. Vérifier les disques avec `qemu-img check` avant premier boot.
8. Démarrer `ubuntu-devops`.
9. Revalider SSH, Internet, DNS et blocage LAN.
10. Revalider toute la pile DevOps/DevSecOps.
11. Produire le verdict de restauration uniquement après validation bout en bout.

## 11. Incident réseau KVM

Si une VM n'a plus Internet :

```bash
virsh -c qemu:///system net-info devops-nat
ip addr show virbr50
virsh -c qemu:///system domiflist ubuntu-devops
```

Ne pas faire de `nft flush ruleset`. Le projet possède ses propres règles et ne doit pas effacer le firewall global du HOST.

## 12. Incident VM

Si `ubuntu-devops` ne démarre pas :

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system dumpxml ubuntu-devops
```

Vérifier ensuite le pool/volume et le QCOW2. Ne supprimer aucun disque tant que sa provenance et son backup ne sont pas confirmés.

## 13. Incident Docker/Kubernetes dans la VM

```bash
systemctl status docker --no-pager
docker info
kubectl version --client
helm version
kind version
```

Si Docker est arrêté : diagnostiquer avant de modifier la configuration. Les outils Kubernetes de ce projet sont des outils client/lab dans la VM ; ne pas installer cette pile sur le HOST pour contourner une panne.

## 14. Logs et preuves

Répertoires du projet :

- `logs/` : journalisation d'exécution ;
- `reports/` : rapports de diagnostic/dry-run ;
- `state/` : état et preuves locales ;
- GitHub Actions : tests, ShellCheck, non-régression et laboratoire VM réel.

Lors d'un incident, conserver le rapport et le log correspondant avant toute correction.

## 15. Rollback / arrêt contrôlé

Si une phase échoue :

1. ne pas poursuivre vers la phase dépendante ;
2. conserver logs et état ;
3. vérifier le rollback automatique lorsqu'il existe ;
4. ne pas supprimer manuellement un disque, réseau ou pool sans inventaire ;
5. revenir au dernier état sauvegardé vérifié si la convergence ne peut pas être rétablie.

Le provisioning VM contient un rollback ciblé pour les ressources créées pendant une tentative échouée.

## 16. Maintenance du dépôt

Avant toute évolution :

```bash
./diagnostic.sh
./install.sh --dry-run
```

Toute modification des scripts mutateurs doit conserver :

- `run_mutating` ;
- les gates fail-closed ;
- les checksums/signatures ;
- la séparation HOST / KVM / VM_DEVOPS / BACKUP ;
- les tests GitHub Actions.

Une nouvelle version n'est pas considérée prête tant que les tests, ShellCheck, non-régression et `vm-pretest` ne sont pas verts.
