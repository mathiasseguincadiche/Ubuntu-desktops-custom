# Réseau KVM — NAT CUSTOM

## Référence figée

- Réseau VM : `192.168.50.0/24`
- Interface/passerelle HOST KVM : `192.168.50.254`
- DHCP : `192.168.50.100-192.168.50.200`
- DNS 1 : `9.9.9.9`
- DNS 2 : `1.1.1.1`
- Bridge libvirt prévu : `virbr50`
- Réseau libvirt : `devops-nat`

## Politique

| Flux | Politique |
|---|---|
| VM → Internet | ALLOW |
| VM → DNS publics configurés | ALLOW |
| VM → VM | ALLOW |
| HOST → VM | ALLOW |
| VM → HOST via réseau KVM | ALLOW |
| VM → LAN physique | BLOCK |
| LAN physique → VM | BLOCK |
| Internet → VM | BLOCK |
| Port-forward entrant | désactivé par défaut |

## Principe d'isolation

Le NAT libvirt seul n'est pas considéré comme une preuve suffisante d'isolation vis-à-vis du LAN physique. La phase d'implémentation devra ajouter une politique de filtrage explicite et testée, sans flush global de nftables/iptables et sans perturber le firewall existant de l'hôte.

## Adressage

- `.1-.99` : hors DHCP ; `.2-.99` réservables aux services/VM à adresse stable.
- `.100-.200` : pool DHCP.
- `.201-.253` : réserve future.
- `.254` : exclusivement passerelle/interface virtuelle de l'hôte.

Les VM importantes, dont `ubuntu-devops`, pourront recevoir une réservation DHCP déterministe.

## Gate de sécurité

Ce document et le XML sont déclaratifs. Aucun réseau n'est créé ou modifié tant que `REAL_MACHINE_APPROVED=false` et que le pré-test n'est pas validé.
