# Network fixtures

Simulation inputs for the future guarded KVM network engine.

Current fixtures:
- `routes-no-conflict.txt`: example physical LAN `10.0.0.0/24`, no overlap with `devops-nat`.
- `routes-conflict.txt`: physical route already using `192.168.50.0/24`; expected future verdict is `BLOCKED / MANUAL_ACTION_REQUIRED`.

Future fixtures will additionally model:
- existing firewall state that must be preserved;
- expected `devops-nat` libvirt XML;
- deterministic DHCP reservations;
- two controlled guest identities for VM↔VM pre-test;
- known reachable physical-LAN target for isolation proof.

These fixtures are simulation inputs only and never modify the workstation.
