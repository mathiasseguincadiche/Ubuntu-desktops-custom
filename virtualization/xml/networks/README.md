# Libvirt network templates

`devops-nat.xml` is the declarative base for the project's isolated KVM NAT network.

It defines only the safe libvirt-local primitives: network name, NAT mode, bridge, gateway and DHCP range. DNS upstream enforcement and physical-LAN isolation are deliberately left to the future guarded network module because they require runtime inspection of the HOST routes/firewall.

No file in this directory is applied automatically during the architecture phase.
