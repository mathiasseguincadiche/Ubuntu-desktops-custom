# Moteur d'orchestration V1

Le moteur commun execute chaque module selon le contrat :

`PRECHECK -> PLAN -> APPLY -> POSTCHECK -> REPORT`

## Garanties

- ordre deterministe d'enregistrement ;
- scope obligatoire `HOST`, `KVM`, `VM_DEVOPS` ou `BACKUP` ;
- dependances bloquees si leur etat n'est pas satisfaisant ;
- reprise avec `ORCH_RESUME=true` pour les modules deja termines ;
- etat persistant par module ;
- rapport final dans `reports/` ;
- `DRY_RUN=true` reste la valeur par defaut ;
- toute mutation reelle continue de passer par `run_mutating`, donc reste bloquee tant que `REAL_MACHINE_APPROVED=false`.

Le moteur ne rend aucun module d'installation actif a lui seul. Il fournit uniquement le cadre d'execution securise et testable.
