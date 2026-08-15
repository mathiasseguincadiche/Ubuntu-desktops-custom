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

@test "host participates on KVM network at gateway address" {
  run grep -F 'KVM_HOST_PARTICIPATES=true' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
  run grep -F 'KVM_HOST_ADDRESS=192.168.50.254' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
  run grep -F 'address: 192.168.50.254' "$REPO_ROOT/manifests/virtualization/networks.yml"
  [ "$status" -eq 0 ]
}

@test "DHCP range is 100 through 200" {
  run grep -F 'KVM_DHCP_START=192.168.50.100' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
  run grep -F 'KVM_DHCP_END=192.168.50.200' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "canonical XML fixture carries gateway and DHCP contract" {
  run grep -F "address='192.168.50.254'" "$REPO_ROOT/tests/fixtures/network/expected-devops-nat.xml"
  [ "$status" -eq 0 ]
  run grep -F "start='192.168.50.100' end='192.168.50.200'" "$REPO_ROOT/tests/fixtures/network/expected-devops-nat.xml"
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

@test "physical LAN is discovered dynamically" {
  run grep -F 'KVM_PHYSICAL_LAN_DETECTION=dynamic-host-routes' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "route fixtures cover overlap and no-overlap cases" {
  run grep -F '192.168.50.0/24' "$REPO_ROOT/tests/fixtures/network/routes-conflict.txt"
  [ "$status" -eq 0 ]
  run grep -F '10.0.0.0/24' "$REPO_ROOT/tests/fixtures/network/routes-no-conflict.txt"
  [ "$status" -eq 0 ]
}

@test "KVM preflight explicitly checks route conflicts" {
  run grep -F 'ensure 192.168.50.0/24 is not already routed/connected' "$REPO_ROOT/modules/virtualization/20_preflight_kvm.sh"
  [ "$status" -eq 0 ]
}

@test "existing host firewall must be preserved" {
  run grep -F 'KVM_PRESERVE_EXISTING_FIREWALL=true' "$REPO_ROOT/config/virtualization.conf"
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

@test "devops VM stable address uses DHCP reservation strategy" {
  run grep -F 'VM_DEVOPS_ADDRESS_MODE=dhcp-reservation' "$REPO_ROOT/config/devops-vm.conf"
  [ "$status" -eq 0 ]
  run grep -F 'address_source: conflict-checked-address-within-dhcp-pool' "$REPO_ROOT/manifests/virtualization/networks.yml"
  [ "$status" -eq 0 ]
}

@test "guest network template remains DHCP client" {
  run grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl"
  [ "$status" -eq 0 ]
}

@test "network plan retains DHCP single authority" {
  run grep -F 'stable VM identities use conflict-checked DHCP reservations' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -eq 0 ]
}

@test "network contract requires dynamic route overlap detection" {
  run grep -F 'reject overlap between 192.168.50.0/24' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -eq 0 ]
}

@test "network rollback is project-owned and targeted" {
  run grep -F 'rollback only project-owned network/firewall changes' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -eq 0 ]
}

@test "validation contract requires blocked LAN proof" {
  run grep -F 'VM -> physical LAN = BLOCKED' "$REPO_ROOT/modules/virtualization/30_virtualization_validation.sh"
  [ "$status" -eq 0 ]
}

@test "real machine gate remains closed" {
  run grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
  [ "$status" -eq 0 ]
}

@test "network apply remains blocked during architecture phase" {
  run bash -c "source '$REPO_ROOT/modules/virtualization/24_networks.sh'; module_apply"
  [ "$status" -eq 8 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "no global firewall flush exists in executable shell code" {
  run bash -c "if grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(nft[[:space:]]+flush[[:space:]]+ruleset|iptables[[:space:]]+-F)([[:space:]]|$)' --include='*.sh' '$REPO_ROOT'; then exit 1; else exit 0; fi"
  [ "$status" -eq 0 ]
}
