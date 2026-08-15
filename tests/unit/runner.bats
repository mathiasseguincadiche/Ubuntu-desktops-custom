#!/usr/bin/env bats
@test 'skeleton runner blocks real command execution' {
  run bash -c 'source lib/runner.sh; run_command echo unsafe'
  [ "$status" -eq 10 ]
}
