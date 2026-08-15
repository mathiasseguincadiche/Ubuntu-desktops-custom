# Ubuntu-desktops-custom

Workstation-as-code pour **Ubuntu Desktop 26.04 LTS** : configuration HOST, virtualisation KVM/libvirt CLI-first, VM Ubuntu Server 26.04 DevOps et sauvegarde/restauration.

Version actuelle : **1.0.0**

## Périmètre

- **HOST** — Ubuntu Desktop 26.04, mises à jour, firmware/microcode AMD, Intel Arc, codecs/multimédia, applications, terminal Bash/Ptyxis, SSH, gaming et validation.
- **KVM** — QEMU/libvirt, `virsh`, OVMF/UEFI, TPM, pools/volumes, catalogue Ubuntu vérifié, réseau NAT custom, SSH et validation.
- **VM_DEVOPS** — Ubuntu Server 26.04 LTS, cloud-init, SSH, Git, Terraform, Ansible, Docker Engine/Buildx/Compose, kubectl, Helm, kind, AWS CLI, Azure CLI et DevSecOps.
- **BACKUP/RESTORE** — Restic chiffré, inventaire, intégrité, rétention, restauration granulaire et disaster recovery.

## Réseau KVM

`devops-nat` utilise `192.168.50.0/24` avec :

- bridge HOST `virbr50` : `192.168.50.254` ;
- DHCP : `192.168.50.100-200` ;
- DNS : `9.9.9.9` et `1.1.1.1` ;
- HOST ↔ VM : autorisé ;
- VM ↔ VM : autorisé ;
- VM → Internet : autorisé ;
- VM → LAN physique : bloqué ;
- LAN → VM : bloqué ;
- Internet → VM : bloqué par défaut.

Voir `docs/NETWORK_KVM_NAT_CUSTOM.md`.

## Sécurité d'exécution

Le chemin d'exécution réelle existe, mais reste **fail-closed** : `REAL_MACHINE_APPROVED=false` est la valeur statique par défaut. `./install.sh --apply` exige notamment un TTY interactif, un diagnostic réel valide, un dry-run réussi sur le même commit, un backup Restic externe vérifié et récent, une confirmation globale exacte et des confirmations séparées pour HOST, KVM, VM_DEVOPS et BACKUP.

Commandes principales :

```bash
./diagnostic.sh
./install.sh --dry-run
./menu.sh
```

Ne lancer `./install.sh --apply` qu'après validation des gates et du backup pré-APPLY.

## Validation GitHub

La V1.0.0 a passé :

- tests unitaires ;
- tests d'intégration ;
- contrats dry-run ;
- ShellCheck ;
- non-régression ;
- **pré-test réel Ubuntu Server 26.04 sous KVM**, incluant installation de la pile DevOps/DevSecOps, smoke tests Docker et test de persistance après reboot.

Dernier verdict de référence du laboratoire VM : `REAL UBUNTU 26.04 VM PRE-TEST PASS`.

## Documentation

- `docs/V1_EXECUTION_CANDIDATE.md` — procédure protégée avant exécution réelle ;
- `docs/NETWORK_KVM_NAT_CUSTOM.md` — contrat réseau KVM ;
- `docs/` — architecture, exploitation et validations complémentaires.
