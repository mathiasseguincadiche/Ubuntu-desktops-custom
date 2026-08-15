#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "network XML is declarative and not an executable script" {
  [ -f "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml" ]
  run grep -F 'Not applied automatically' "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
  [ "$status" -eq 0 ]
}

@test "architecture network module cannot apply changes" {
  run bash -c "source '$REPO_ROOT/modules/virtualization/24_networks.sh'; module_apply"
  [ "$status" -eq 8 ]
}

@test "network module contains no virsh net-define apply command yet" {
  run grep -E '^[[:space:]]*virsh([[:space:]].*)?net-define' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -ne 0 ]
}
