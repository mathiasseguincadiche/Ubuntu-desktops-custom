#!/usr/bin/env bats
@test 'scope guard accepts identical scopes' {
  run bash -c 'source lib/scope.sh; assert_scope VM_DEVOPS VM_DEVOPS'
  [ "$status" -eq 0 ]
}
@test 'scope guard rejects cross-scope execution' {
  run bash -c 'source lib/scope.sh; assert_scope VM_DEVOPS HOST'
  [ "$status" -ne 0 ]
}
