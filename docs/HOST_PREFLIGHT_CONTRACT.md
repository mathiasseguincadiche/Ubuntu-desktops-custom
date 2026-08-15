# HOST preflight contract

Le premier module HOST est strictement read-only. Il doit établir que la workstation observée correspond au socle attendu avant toute installation.

## Contrôles bloquants

- Ubuntu `26.04` ;
- architecture x86_64 et virtualisation AMD-V/SVM disponible ;
- `/dev/kvm` disponible ;
- partition racine EXT4 ;
- volume DATA monté en EXT4 à l'emplacement configuré ;
- détection du CPU Ryzen 7 7700 et du GPU Intel Arc B580 lorsque `HARDWARE_MATCH_REQUIRED=true`.

## Inventaire non destructif

Le rapport conserve également les informations `lspci`, `lsblk`, Secure Boot et routes IPv4 nécessaires aux modules pilotes, gaming et KVM suivants.

Le module ne peut installer de paquet, modifier un service, monter/formater un disque ou modifier le firewall. Son `APPLY` est volontairement un no-op.
