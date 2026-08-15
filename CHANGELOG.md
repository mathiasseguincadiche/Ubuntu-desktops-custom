# Changelog

## Unreleased

### Architecture
- Squelette V1 HOST / KVM / VM_DEVOPS / BACKUP.
- Réseau KVM `devops-nat` figé sur `192.168.50.0/24` avec autostart.
- Passerelle/interface HOST `192.168.50.254` via `virbr50`.
- DHCP `192.168.50.100-200` et réservations déterministes dans ce pool.
- Contrat DNS Quad9 `9.9.9.9` + Cloudflare `1.1.1.1`.
- Isolation explicite VM → LAN physique avec découverte dynamique des routes.
- HOST ↔ VM, VM ↔ VM et VM → Internet autorisés.
- Aucun port-forward entrant par défaut.
- Blocage sur chevauchement réseau ou ambiguïté.
- Préservation du firewall HOST et rollback limité aux objets du projet.
- Validation future de la persistance après redémarrage.
- Gate `REAL_MACHINE_APPROVED=false` maintenue.
- Tests Bats et CI de non-régression du contrat réseau.
