# HOST preflight contract

Le premier module HOST est strictement read-only. Il doit établir que la workstation observée correspond au socle attendu avant toute installation.

## Contrôles bloquants

- Ubuntu `26.04` ;
- architecture x86_64 et virtualisation AMD-V/SVM disponible ;
- `/dev/kvm` disponible ;
- partition racine EXT4 ;
- volume DATA monté en EXT4 à l'emplacement configuré ;
- détection du CPU Ryzen 7 7700 et du GPU Intel Arc B580 lorsque `HARDWARE_MATCH_REQUIRED=true` ;
- `dpkg --audit` vide ;
- aucun verrou réellement détenu sur les fichiers de lock APT/dpkg ou sur le lock d'exécution `unattended-upgrades`.

## Santé APT / dpkg

Le préflight ne bloque pas sur le seul nom d'un processus. Ubuntu maintient normalement `unattended-upgrade-shutdown --wait-for-signal` comme service de veille ; sa présence n'indique pas qu'une transaction APT est active.

Le contrôle fail-closed porte donc sur les détenteurs réels des verrous :

```text
/var/lib/dpkg/lock-frontend
/var/lib/dpkg/lock
/var/cache/apt/archives/lock
/var/lib/apt/lists/lock
/run/unattended-upgrades.lock
```

Si un de ces verrous est détenu ou si `dpkg --audit` rapporte un état incomplet, le PRECHECK doit retourner `EXIT_PRECHECK_FAILED` immédiatement. Les assertions du préflight propagent explicitement leur code retour ; elles ne dépendent pas du comportement implicite de `set -e` lorsqu'une phase est appelée depuis une condition Bash.

## Inventaire non destructif

Le rapport conserve également les informations `lspci`, `lsblk`, Secure Boot, routes IPv4, audit dpkg et verrous package-manager nécessaires aux modules suivants.

Le module ne peut installer de paquet, modifier un service, monter/formater un disque ou modifier le firewall. Son `APPLY` est volontairement un no-op.
