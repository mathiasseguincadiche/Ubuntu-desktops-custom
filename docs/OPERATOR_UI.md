# Interface opérateur V3

## Objectif

Le terminal sert à comprendre et piloter l'exécution. Les détails techniques servent au diagnostic et à l'audit.

Le projet sépare donc deux niveaux d'information :

- **terminal opérateur** : sections claires, étapes numérotées, sous-actions métier, statuts, durées, preuves de validation, verdict et prochaine action ;
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

## Progression live V3 pendant l'APPLY réel

Une étape de haut niveau peut contenir plusieurs mutations longues. Le mode opérateur affiche donc, uniquement pendant un APPLY réel validé, la sous-action mutante en cours avec un libellé humain et la durée lorsque l'action se termine.

Exemple HOST :

```text
  [04/41] Intel Arc B580 et pile graphique .............. EN COURS
          ├─ Mesa/Vulkan + Intel VA-API + GPU tools ..... OK · 9s
  [04/41] Intel Arc B580 et pile graphique .............. OK
          Arc B580 PCI 8086:e20b | driver xe | Vulkan Intel Mesa | probe VA-API

  [05/41] Multimédia et codecs .......................... EN COURS
          ├─ FFmpeg + GStreamer + PipeWire/WirePlumber .. OK · 7s
          ├─ VLC — canal officiel VideoLAN Snap ......... OK · 14s
  [05/41] Multimédia et codecs .......................... OK
          FFmpeg | GStreamer base/good/bad/ugly/libav | PipeWire/WirePlumber | VLC
```

Exemple VM_DEVOPS :

```text
  [28/41] Docker Engine ................................. EN COURS
          ├─ Docker Engine + Buildx + Compose ........... OK · 18s
  [28/41] Docker Engine ................................. OK
          Docker Engine | Buildx | Compose plugin | service et droits utilisateur
```

Les commandes exactes ne sont jamais recopiées dans cette vue. Elles restent dans `commands.log`, tandis que leurs sorties restent dans `modules.log` et les traces moteur dans `main.log`.

## Granularité couverte

La télémétrie V3 est branchée au niveau central de `run_mutating` et couvre les mutations des domaines :

- **HOST** : mises à jour Ubuntu, microcode/firmware, Intel Arc/Mesa/Vulkan/VA-API, multimédia, applications desktop, terminal, gaming et observabilité ;
- **KVM** : QEMU/libvirt, droits, OVMF/swtpm, stockage, pools, réseau `devops-nat`, garde nftables et catalogue Canonical ;
- **VM_DEVOPS** : identité/SSH, cloud-init, image Ubuntu, provisionnement, outils de base, Git, cloud CLIs, IaC, Docker, Kubernetes et DevSecOps.

Les modules BACKUP du plan d'architecture restent non-mutants. Leur détail opérateur décrit le contrat et les contrôles attendus ; la vraie préparation Restic pré-APPLY conserve sa propre interface détaillée avec snapshot, restore-test, intégrité et preuve `BACKUP_VERIFIED`.

## Preuve après chaque module

`lib/operator_details.sh` fournit un détail humain non vide pour chacun des 41 modules. Après un `OK`, l'opérateur voit donc ce qui vient réellement d'être validé au lieu d'un verdict opaque.

Cette couche ne lance aucune commande et ne prend aucune décision de sécurité. Elle ne fait qu'expliquer le résultat déjà produit par le module.

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

Une sous-action mutante en échec passe immédiatement de `EN COURS` à `ÉCHEC` avec sa durée, puis le module et l'orchestrateur conservent leur comportement fail-closed habituel.

Une erreur ne doit jamais être masquée pour rendre l'interface plus esthétique.

## Contrat de non-régression

La CI vérifie notamment que :

- `lib/ui.sh` reste la couche UI centrale ;
- `lib/operator_details.sh` fournit un détail pour chacun des 41 modules ;
- `lib/live_progress.sh` fournit uniquement la télémétrie opérateur des mutations réelles ;
- les bundles HOST/KVM/VM_DEVOPS majeurs ont des libellés métier explicites ;
- la durée est affichée à la fin d'une sous-action réelle ;
- les commandes complètes restent journalisées ;
- les phases des 41 modules sont redirigées vers le log technique en mode opérateur ;
- le dry-run n'active pas la progression live des mutations ;
- un code retour d'échec d'une commande reste inchangé après affichage de la sous-action ;
- le menu conserve l'ordre sécurisé `1 -> 2 -> 3 -> 4` ;
- le backup Restic conserve ses gates fail-closed, son restore-test et `BACKUP_VERIFIED`.
