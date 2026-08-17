# Watchdog des mutations REAL APPLY

## Objectif

Le moteur ne doit jamais laisser une mutation réelle sembler active alors qu'un sous-processus Linux est en réalité suspendu par le job-control (`ps STAT=T` ou `T+`).

L'incident de référence a été observé pendant l'installation de Proton Mail : `apt-get` avait terminé le paramétrage du paquet mais restait suspendu en `T+`, conservait les verrous APT/dpkg et bloquait toute la chaîne `run_mutating` sans nouvelle sortie.

Le correctif est central et ne dépend pas de Proton Mail. Il protège toutes les mutations HOST, KVM et VM_DEVOPS exécutées par `run_mutating`.

## Architecture

`lib/runner.sh` conserve la commande réelle au premier plan afin de ne pas changer les sémantiques TTY et `sudo` existantes.

En parallèle, `lib/process_watchdog.sh` lance un sidecar léger qui :

1. inspecte uniquement les descendants du shell runner courant ;
2. ignore son propre sous-arbre de surveillance ;
3. détecte les états Linux `T`/`T+` ;
4. attend une période de grâce configurable ;
5. journalise le PID, l'état et la commande ;
6. tente au maximum une reprise `SIGCONT` lorsque la politique l'autorise ;
7. exige une action opérateur si la reprise automatique est impossible ou si le même PID se suspend de nouveau.

Aucune terminaison destructive d'un gestionnaire de paquets n'est automatisée.

## Politique par défaut

La politique se trouve dans `config/security.conf` :

```bash
MUTATION_WATCHDOG_ENABLED=true
MUTATION_WATCHDOG_POLL_SECONDS=1
MUTATION_WATCHDOG_STOP_GRACE_SECONDS=5
MUTATION_WATCHDOG_AUTO_CONTINUE=true
MUTATION_WATCHDOG_MAX_AUTO_CONTINUES=1
```

Le délai de 5 secondes évite de réagir à un état transitoire très bref.

Une seule reprise automatique est autorisée par PID. Cette reprise utilise d'abord le signal direct lorsque les permissions le permettent, puis `sudo -n` pour un descendant appartenant à root. `sudo -n` est obligatoire afin que le watchdog ne puisse jamais créer un prompt de mot de passe invisible.

## Affichage opérateur

`lib/process_watchdog_ui.sh` écrit directement sur `/dev/tty` afin que l'alerte reste visible même quand stdout/stderr du module est redirigé dans `modules.log`.

Exemple :

```text
          ├─ WATCHDOG — processus suspendu ............ ATTENTION
             PID 156160 | état T+ | suspendu 5s
             Commande: apt-get -y install ...
             Action: Processus enfant suspendu par job-control; la mutation ne progresse plus.
          ├─ WATCHDOG — reprise automatique SIGCONT ... INFO
          ├─ Proton Mail Desktop ....................... EN COURS · 8s
```

Si la reprise ne peut pas être faite automatiquement :

```text
          ├─ WATCHDOG — intervention opérateur requise  BLOQUÉ
             Action: ... exécuter: sudo kill -CONT <PID>
```

La mutation reste alors suspendue : les étapes suivantes ne sont pas exécutées.

## Traces et état courant

Chaque run réel peut produire :

```text
logs/<RUN_ID>/process-watchdog.log
state/runs/<RUN_ID>/process-watchdog.status
```

Le fichier d'état contient notamment :

```text
state=SUSPENDED|AUTO_CONTINUE|RECOVERED|MANUAL_ACTION
scope=HOST|KVM|VM_DEVOPS
pid=<PID>
stat=T+
stopped_for_seconds=<N>
command=<commande>
detail=<diagnostic>
updated_at=<timestamp>
```

Depuis une deuxième fenêtre, l'état courant est donc consultable sans perturber l'APPLY :

```bash
RUN_ID="$(cat state/latest)"
cat "state/runs/$RUN_ID/process-watchdog.status" 2>/dev/null || true
tail -F "logs/$RUN_ID/process-watchdog.log"
```

## Préflight après une interruption

Une interruption manuelle peut laisser soit un ancien `apt`/`apt-get`/`dpkg` actif, soit une base dpkg incomplète.

Le module `host.preflight` vérifie désormais en lecture seule :

- que `dpkg --audit` ne remonte aucune anomalie ;
- qu'aucun processus APT/dpkg/unattended-upgrade/PackageKit n'est encore actif avant le REAL APPLY.

Si l'un de ces contrôles échoue, le REAL APPLY est refusé avant toute nouvelle mutation.

## Sécurité

Le watchdog ne remplace aucun gate existant :

- dry-run du commit courant ;
- worktree Git propre ;
- backup Restic vérifié ;
- confirmation exacte ;
- confirmations de scope ;
- fail-closed KVM/backup.

Il ajoute uniquement une protection d'exécution contre l'attente silencieuse d'un sous-processus suspendu.
