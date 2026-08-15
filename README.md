# Ubuntu-desktops-custom

Architecture reproductible d'une workstation Ubuntu Desktop 26.04 LTS orientée desktop, gaming, virtualisation KVM/libvirt CLI-first et VM Ubuntu Server DevOps.

> **Gate actuelle : architecture/pré-test uniquement.** `REAL_MACHINE_APPROVED=false`. Aucun script du projet ne doit modifier une workstation réelle avant validation complète du pré-test.

## Domaines

- **HOST** — Ubuntu Desktop, matériel, pilotes/firmware, applications, terminal, multimédia et gaming.
- **KVM** — QEMU/libvirt, UEFI/TPM, pools, catalogue OS/ISO et réseau NAT custom.
- **VM_DEVOPS** — Ubuntu Server 26.04 LTS et pile Git/Docker/Kubernetes/Terraform/Ansible/Cloud/DevSecOps.
- **BACKUP** — sauvegarde, vérification, restauration et disaster recovery.

## Réseau KVM figé

`devops-nat` utilise `192.168.50.0/24`, passerelle HOST `192.168.50.254`, DHCP `192.168.50.100-200`, DNS `9.9.9.9` et `1.1.1.1`. Les VM accèdent à Internet par NAT et communiquent avec l'hôte et entre elles ; l'accès initié vers le LAN physique est bloqué par politique. Aucun port-forward entrant n'est activé par défaut.

Voir `docs/NETWORK_KVM_NAT_CUSTOM.md`.

## État du projet

Le dépôt contient actuellement le squelette architectural, les contrats et les tests de garde. Les modules d'installation réelle restent volontairement bloqués.
