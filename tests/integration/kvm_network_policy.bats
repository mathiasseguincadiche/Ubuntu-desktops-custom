#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "custom KVM network uses expected CIDR" {
  run grep -F 'KVM_NETWORK_CIDR=192.168.50.0/24' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "custom KVM gateway is .254" {
  run grep -F 'KVM_GATEWAY=192.168.50.254' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "DHCP range is 100 through 200" {
  run grep -F 'KVM_DHCP_START=192.168.50.100' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
  run grep -F 'KVM_DHCP_END=192.168.50.200' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "DNS policy uses Quad9 and Cloudflare" {
  run grep -F 'KVM_DNS_1=9.9.9.9' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
  run grep -F 'KVM_DNS_2=1.1.1.1' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "physical LAN access is blocked by policy" {
  run grep -F 'vm_to_physical_lan: block' "$REPO_ROOT/manifests/virtualization/networks.yml"
  [ "$status" -eq 0 ]
}

@test "inbound forwarding is disabled by default" {
  run grep -F 'inbound_port_forwarding: disabled' "$REPO_ROOT/manifests/virtualization/networks.yml"
  [ "$status" -eq 0 ]
}

@test "devops VM is bound to custom NAT" {
  run grep -F 'VM_DEVOPS_NETWORK=devops-nat' "$REPO_ROOT/config/devops-vm.conf"
  [ "$status" -eq 0 ]
}
