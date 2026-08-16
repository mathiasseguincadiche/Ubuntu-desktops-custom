# Interface opérateur V2

## Objectif

Le terminal sert à comprendre et piloter l'exécution. Les détails techniques servent au diagnostic et à l'audit.

Le projet sépare donc deux niveaux d'information :

- **terminal opérateur** : sections claires, étapes numérotées, statuts, explications courtes, verdict et prochaine action ;
- **logs techniques** : timestamps, phases PRECHECK/PLAN/APPLY/POSTCHECK, commandes exactes, sorties détaillées et traces de sous-processus.

Aucun gate de sécurité n'est modifié par cette couche d'affichage.

## Parcours principal

Le menu conserve le parcours simple :

1. diagnostic global ;
2. dry-run complet ;
3. backup pré-APPLY Restic ;
4. installation réelle protégée.

Les autres options restent regroupées sous `OUTILS`.

## Statuts terminal

Les statuts opérateur sont volontairement limités :

- `OK` ;
- `EN COURS` ;
- `INFO` ;
- `ATTENTION` ;
- `BLOQUÉ` ;
- `ÉCHEC` ;
- `IGNORÉ`.

Les couleurs sont activées uniquement sur un terminal compatible. La variable standard `NO_COLOR` désactive les couleurs.

## Progression live pendant l'APPLY réel

Une étape de haut niveau peut contenir plusieurs mutations longues. Le mode opérateur affiche donc, uniquement pendant un APPLY réel validé, la sous-action mutante en cours avec un libellé humain.

Exemple pour `host.apps` :

```text
  [06/41] Applications desktop ............................ EN COURS
          ├─ Nettoyage des applications retirées .......... OK
          ├─ Paquets Ubuntu — FileZilla, Remmina… ......... OK
          ├─ Firefox — dépôt officiel Mozilla ............. OK
          ├─ Proton Mail Desktop ........................... EN COURS
```

Les commandes exactes ne sont jamais recopiées dans cette vue. Elles restent dans `commands.log`, tandis que leurs sorties restent dans `modules.log` et les traces moteur dans `main.log`.

Cette télémétrie live est centralisée dans `lib/live_progress.sh` et branchée sur `run_mutating` dans `lib/runner.sh`. Elle couvre les principales mutations HOST, KVM et VM_DEVOPS sans modifier leurs gates ni leur comportement fonctionnel.

Le dry-run n'affiche pas ces sous-actions mutantes en direct : il conserve sa vue synthétique des 41 modules et journalise les commandes simulées dans les logs techniques.

## Logs d'une exécution

Chaque `RUN_ID` possède un répertoire sous `logs/` :

```text
logs/<RUN_ID>/
├── main.log       # moteur, timestamps, états et messages internes
├── commands.log   # commandes exactes après redaction des secrets
└── modules.log    # sorties détaillées des phases et sous-processus
```

Les workflows Restic ajoutent également des logs dédiés, par exemple `restic.log` ou `restic-verify.log`.

Le terminal affiche le chemin des logs en début ou en fin d'exécution afin que le diagnostic complet reste disponible sans polluer l'écran.

## Mode technique

L'interface opérateur est le mode par défaut. Pour une session de diagnostic volontairement verbeuse :

```bash
UW_UI_MODE=technical ./install.sh --dry-run
```

Ce mode réactive l'affichage des messages moteur détaillés. Il ne change ni le dry-run, ni les gates, ni les mutations autorisées.

## Erreurs

Une erreur opérateur doit répondre immédiatement à quatre questions :

1. quel est le problème ;
2. quelle est la conséquence ;
3. quelle action effectuer ;
4. où trouver le log technique.

Une sous-action mutante en échec passe immédiatement de `EN COURS` à `ÉCHEC`, puis le module et l'orchestrateur conservent leur comportement fail-closed habituel.

Une erreur ne doit jamais être masquée pour rendre l'interface plus esthétique.

## Contrat de non-régression

La CI vérifie notamment que :

- `lib/ui.sh` reste la couche UI centrale ;
- `lib/live_progress.sh` fournit uniquement la télémétrie opérateur des mutations réelles ;
- les commandes complètes restent journalisées ;
- les phases des 41 modules sont redirigées vers le log technique en mode opérateur ;
- le dry-run n'active pas la progression live des mutations ;
- un code retour d'échec d'une commande reste inchangé après affichage de la sous-action ;
- le menu conserve l'ordre sécurisé `1 -> 2 -> 3 -> 4` ;
- le backup Restic conserve ses gates fail-closed, son restore-test et `BACKUP_VERIFIED`.
