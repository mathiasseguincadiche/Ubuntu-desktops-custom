#!/usr/bin/env bats

@test "custom KVM network uses expected CIDR" {
  run grep -F 'KVM_NETWORK_CIDR=192.168.50.0/24' config/virtualization.conf
  [ "$status" -eq 0 ]
}

@test "custom KVM gateway is .254" {
  run grep -F 'KVM_GATEWAY=192.168.50.254' config/virtualization.conf
  [ "$status" -eq 0 ]
}

@test "physical LAN access is blocked by policy" {
  run grep -F 'vm_to_physical_lan: block' manifests/virtualization/networks.yml
  [ "$status" -eq 0 ]
}

@test "inbound forwarding is disabled by default" {
  run grep -F 'inbound_port_forwarding: disabled' manifests/virtualization/networks.yml
  [ "$status" -eq 0 ]
}
