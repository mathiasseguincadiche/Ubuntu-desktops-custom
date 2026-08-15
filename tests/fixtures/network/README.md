# Network fixtures

Future fixtures will model:

- clean HOST route table with no `192.168.50.0/24` overlap;
- conflicting HOST route using `192.168.50.0/24`;
- physical LAN route discovery;
- existing firewall state that must be preserved;
- expected `devops-nat` libvirt XML;
- deterministic DHCP reservations;
- two controlled guest identities for VM↔VM pre-test.

These fixtures are simulation inputs only and never modify the workstation.
