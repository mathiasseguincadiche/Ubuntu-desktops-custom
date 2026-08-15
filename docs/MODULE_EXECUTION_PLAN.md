# Plan d'execution des modules

Le catalogue `manifests/module-plan.conf` fige l'ordre logique sans sourcer ni executer les scripts de modules. Il est volontairement hors de `config/`, reserve aux variables runtime `KEY=VALUE` validees par le chargeur securise.

Ordre actuel :

1. HOST preflight
2. HOST validation
3. KVM preflight
4. KVM network
5. KVM validation
6. VM DEVOPS preflight
7. VM DEVOPS Docker
8. VM DEVOPS validation
9. BACKUP preflight
10. BACKUP validation

Les dependances sont validees avant toute future execution. Un chemin sortant de `modules/` ou une dependance inconnue est refuse.

Cette etape reste purement declarative. L'adaptateur qui reliera chaque script au moteur `PRECHECK -> PLAN -> APPLY -> POSTCHECK` sera implemente et pre-teste separement. Aucun module n'est automatiquement source par le catalogue.
