# Network fixtures

Simulation inputs for the future guarded KVM network engine.

Current fixtures:
- `routes-no-conflict.txt`: example physical LAN `10.0.0.0/24`, no overlap with `devops-nat`.
- `routes-conflict.txt`: physical route already using `192.168.50.0/24`; expected future verdict is `BLOCKED / MANUAL_ACTION_REQUIRED`.
- `expected-devops-nat.xml`: canonical safe libvirt-local network structure before runtime DNS/isolation enforcement.
- `firewall-existing.txt`: synthetic pre-existing HOST firewall state that project rollback must preserve.
- `dhcp-reservation-example.xml`: synthetic deterministic DHCP reservation inside `.100-.200`; not the final `ubuntu-devops` identity.

Future fixtures will additionally model:
- two controlled guest identities for VM↔VM pre-test;
- known reachable physical-LAN target for isolation proof.

These fixtures are simulation inputs only and never modify the workstation.
