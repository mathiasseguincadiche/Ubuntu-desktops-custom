#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "custom KVM network uses frozen addressing" {
  grep -F 'KVM_NETWORK_CIDR=192.168.50.0/24' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_GATEWAY=192.168.50.254' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DHCP_START=192.168.50.100' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DHCP_END=192.168.50.200' "$REPO_ROOT/config/virtualization.conf"
}

@test "custom KVM network is persistent and host participates" {
  grep -F 'KVM_NETWORK_AUTOSTART=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_HOST_PARTICIPATES=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_HOST_ADDRESS=192.168.50.254' "$REPO_ROOT/config/virtualization.conf"
}

@test "DNS contract uses libvirt Quad9 and Cloudflare forwarders" {
  grep -F 'KVM_DNS_1=9.9.9.9' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DNS_2=1.1.1.1' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DNS_ENFORCEMENT=libvirt-dns-forwarders' "$REPO_ROOT/config/virtualization.conf"
  grep -F "<forwarder addr='9.9.9.9'/>" "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
  grep -F "<forwarder addr='1.1.1.1'/>" "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
}

@test "network policy is fail closed and project firewall is isolated" {
  grep -F 'KVM_FAIL_CLOSED=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_PRESERVE_EXISTING_FIREWALL=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_FIREWALL_ENFORCEMENT=project-nftables-guard' "$REPO_ROOT/config/virtualization.conf"
  grep -F "TABLE_NAME='ubuntu_desktops_custom_kvm'" "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  grep -F 'fail_closed: true' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'vm_to_physical_lan: block' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'inbound_port_forwarding: disabled' "$REPO_ROOT/manifests/virtualization/networks.yml"
}

@test "physical LAN detection and overlap handling remain dynamic" {
  grep -F 'KVM_PHYSICAL_LAN_DETECTION=dynamic-host-routes' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_ROUTE_OVERLAP_ACTION=block' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'ip -4 route show scope link' "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  grep -F 'kvm.overlaps(network)' "$REPO_ROOT/modules/virtualization/24_networks.sh"
}

@test "project guard blocks both directions only for host-connected networks" {
  grep -F 'iifname "%s" ip daddr @blocked_local_ipv4 drop' "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  grep -F 'oifname "%s" ip saddr @blocked_local_ipv4 drop' "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
  grep -F 'policy accept' "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
}

@test "project guard never flushes global firewall" {
  run grep -R -n -E 'nft[[:space:]]+flush[[:space:]]+ruleset|iptables[[:space:]]+-F' "$REPO_ROOT/scripts/kvm" "$REPO_ROOT/modules/virtualization"
  [ "$status" -ne 0 ]
  grep -F 'delete table "$TABLE_FAMILY" "$TABLE_NAME"' "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
}

@test "DHCP reservation is the single guest addressing authority" {
  grep -F 'VM_DEVOPS_ADDRESS_MODE=dhcp-reservation' "$REPO_ROOT/config/devops-vm.conf"
  grep -F 'address_source: conflict-checked-address-within-dhcp-pool' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl"
}

@test "network apply uses secure runner and fail-closed order" {
  grep -F 'run_mutating KVM sudo systemctl enable --now ubuntu-desktops-custom-kvm-guard.service' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  grep -F 'run_mutating KVM sudo virsh --connect "$uri" net-define "$xml"' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  grep -F 'run_mutating KVM sudo virsh --connect "$uri" net-start "$network"' "$REPO_ROOT/modules/virtualization/24_networks.sh"
}

@test "network service persists project guard across reboot" {
  grep -F 'WantedBy=multi-user.target' "$REPO_ROOT/virtualization/systemd/ubuntu-desktops-custom-kvm-guard.service"
  grep -F 'ExecStart=/usr/local/libexec/ubuntu-desktops-custom/kvm-network-guard apply' "$REPO_ROOT/virtualization/systemd/ubuntu-desktops-custom-kvm-guard.service"
}

@test "real machine gate remains closed" {
  grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
}
