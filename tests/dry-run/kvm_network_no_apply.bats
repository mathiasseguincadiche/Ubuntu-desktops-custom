#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "network XML is declarative and not an executable script" {
  [ -f "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml" ]
  run grep -F 'Not applied automatically' "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
  [ "$status" -eq 0 ]
}

@test "architecture network contract cannot apply changes" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/common.sh'; source '$REPO_ROOT/lib/logging.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/modules/virtualization/24_networks.sh'; CURRENT_SCOPE=KVM; kvm_network_apply"
  [ "$status" -eq 8 ]
  [[ "$output" == *'BLOCKED'* ]]
}

@test "network module contains no active virsh network mutation yet" {
  run grep -E '^[[:space:]]*virsh([[:space:]].*)?(net-define|net-start|net-autostart|net-update|net-destroy|net-undefine)([[:space:]]|$)' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -ne 0 ]
}

@test "network module contains no active firewall mutation yet" {
  run grep -E '^[[:space:]]*(sudo[[:space:]]+)?(nft|iptables)([[:space:]]|$)' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -ne 0 ]
}
