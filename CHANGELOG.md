# Changelog

## Unreleased

### Architecture
- Squelette V1 HOST / KVM / VM_DEVOPS / BACKUP.
- Réseau KVM `devops-nat` figé sur `192.168.50.0/24`.
- Passerelle HOST `192.168.50.254`.
- DHCP `192.168.50.100-200`.
- Contrat DNS Quad9 `9.9.9.9` + Cloudflare `1.1.1.1`.
- Isolation explicite VM → LAN physique.
- HOST ↔ VM, VM ↔ VM et VM → Internet autorisés.
- Aucun port-forward entrant par défaut.
- Détection dynamique des routes LAN et blocage sur chevauchement.
- Réservation DHCP déterministe pour les VM importantes.
- Gate `REAL_MACHINE_APPROVED=false` maintenue.
- Tests Bats et CI de non-régression du contrat réseau.
