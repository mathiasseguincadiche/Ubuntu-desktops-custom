#!/usr/bin/env bats

@test "network XML is declarative and not an executable script" {
  [ -f virtualization/xml/networks/devops-nat.xml ]
  run grep -F 'Not applied automatically' virtualization/xml/networks/devops-nat.xml
  [ "$status" -eq 0 ]
}
