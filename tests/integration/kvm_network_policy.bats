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

@test "DNS contract uses Quad9 and Cloudflare" {
  grep -F 'KVM_DNS_1=9.9.9.9' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DNS_2=1.1.1.1' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DNS_ENFORCEMENT=implementation-pending-pretest' "$REPO_ROOT/config/virtualization.conf"
}

@test "network policy is fail closed and preserves host firewall" {
  grep -F 'KVM_FAIL_CLOSED=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_PRESERVE_EXISTING_FIREWALL=true' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'fail_closed: true' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'vm_to_physical_lan: block' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'inbound_port_forwarding: disabled' "$REPO_ROOT/manifests/virtualization/networks.yml"
}

@test "physical LAN detection and overlap handling remain dynamic" {
  grep -F 'KVM_PHYSICAL_LAN_DETECTION=dynamic-host-routes' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_ROUTE_OVERLAP_ACTION=block' "$REPO_ROOT/config/virtualization.conf"
  grep -F '192.168.50.0/24' "$REPO_ROOT/tests/fixtures/network/routes-conflict.txt"
  grep -F '10.0.0.0/24' "$REPO_ROOT/tests/fixtures/network/routes-no-conflict.txt"
}

@test "DHCP reservation is the single guest addressing authority" {
  grep -F 'VM_DEVOPS_ADDRESS_MODE=dhcp-reservation' "$REPO_ROOT/config/devops-vm.conf"
  grep -F 'address_source: conflict-checked-address-within-dhcp-pool' "$REPO_ROOT/manifests/virtualization/networks.yml"
  grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl"
}

@test "network plan preserves connectivity and isolation requirements" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/common.sh'; source '$REPO_ROOT/lib/logging.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/modules/virtualization/24_networks.sh'; CURRENT_SCOPE=KVM; kvm_network_plan"
  [ "$status" -eq 0 ]
  [[ "$output" == *'HOST<->VM'* ]]
  [[ "$output" == *'VM<->VM'* ]]
  [[ "$output" == *'VM->Internet NAT allowed'* ]]
  [[ "$output" == *'VM->physical-LAN blocked'* ]]
  [[ "$output" == *'targeted rollback'* ]]
  [[ "$output" == *'reboot persistence'* ]]
}

@test "KVM validation retains blocked LAN and persistence proof" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/common.sh'; source '$REPO_ROOT/lib/logging.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/modules/virtualization/30_virtualization_validation.sh'; CURRENT_SCOPE=KVM; kvm_validation_plan"
  [ "$status" -eq 0 ]
  [[ "$output" == *'VM->physical-LAN BLOCKED'* ]]
  [[ "$output" == *'devops-nat persistence'* ]]
  [[ "$output" == *'idempotence'* ]]
}

@test "real machine gate remains closed" {
  grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
}

@test "network apply remains security blocked during architecture phase" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/common.sh'; source '$REPO_ROOT/lib/logging.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/modules/virtualization/24_networks.sh'; CURRENT_SCOPE=KVM; kvm_network_apply"
  [ "$status" -eq 8 ]
  [[ "$output" == *'BLOCKED'* ]]
}

@test "KVM network modules contain no active mutation commands" {
  run grep -R -n -E '^[[:space:]]*virsh([[:space:]].*)?(net-define|net-start|net-update|net-destroy|net-undefine)|^[[:space:]]*(sudo[[:space:]]+)?(nft|iptables)([[:space:]]|$)' "$REPO_ROOT/modules/virtualization"
  [ "$status" -ne 0 ]
}
