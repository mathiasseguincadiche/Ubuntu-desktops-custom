# Network addressing is provided by libvirt devops-nat DHCP.
# Important VM identities use deterministic DHCP reservations in libvirt.
# No guest-side static address is hard-coded here to avoid dual sources of truth.
network:
  version: 2
  ethernets:
    primary:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: false
