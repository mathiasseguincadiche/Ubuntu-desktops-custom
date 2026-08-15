#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "network XML is declarative and not an executable script" {
  [ -f "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml" ]
  run grep -F 'Not applied automatically' "$REPO_ROOT/virtualization/xml/networks/devops-nat.xml"
  [ "$status" -eq 0 ]
}
