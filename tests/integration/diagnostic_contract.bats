#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "global diagnostic passes with the supported physical HOST fixture" {
  run env \
    HOST_PROBE_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/host" \
    REPORT_ROOT="$BATS_TEST_TMPDIR/reports" \
    STATE_ROOT="$BATS_TEST_TMPDIR/state" \
    LOG_ROOT="$BATS_TEST_TMPDIR/logs" \
    RUN_ID='diagnostic-fixture' \
    bash "$REPO_ROOT/diagnostic.sh"

  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&2
  fi

  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALLER GATE"*"guarded --apply path enforced"* ]]
  [[ "$output" == *"MUTATION BOUNDARIES"*"read-only probes are allowed"* ]]
  [[ "$output" == *"PHYSICAL HOST PREFLIGHT"*"compatibility checks passed"* ]]
  [[ "$output" == *"REAL MACHINE APPLY GATE: CLOSED BY DEFAULT (EXPECTED)"* ]]
  [[ "$output" == *"NEXT STEP: FULL DRY-RUN"* ]]
  [[ "$output" == *"VERDICT: GO DIAGNOSTIC"* ]]
}

@test "mutation boundary audit allows read-only virsh systemctl and nft probes" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/modules"
  cat > "$BATS_TEST_TMPDIR/repo/modules/read-only.sh" <<'EOF'
sudo virsh --connect qemu:///system net-info devops-nat
sudo virsh --connect qemu:///system net-dumpxml devops-nat
sudo systemctl is-active --quiet libvirtd
sudo nft list table inet ubuntu_desktops_custom_kvm
qemu-img check /tmp/test.qcow2
EOF

  run bash -c "
    source '$REPO_ROOT/lib/pretest_audit.sh'
    REPO_ROOT='$BATS_TEST_TMPDIR/repo'
    pretest_reset
    pretest_check_mutation_boundaries
    printf 'ok=%s ko=%s detail=%s\n' \"\$PRETEST_OK\" \"\$PRETEST_KO\" \"\${PRETEST_LINES[*]}\"
    (( PRETEST_KO == 0 ))
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"read-only probes are allowed"* ]]
}

@test "mutation boundary audit still rejects raw libvirt mutation" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/modules"
  cat > "$BATS_TEST_TMPDIR/repo/modules/raw-mutation.sh" <<'EOF'
sudo virsh --connect qemu:///system net-start devops-nat
EOF

  run bash -c "
    source '$REPO_ROOT/lib/pretest_audit.sh'
    REPO_ROOT='$BATS_TEST_TMPDIR/repo'
    pretest_reset
    pretest_check_mutation_boundaries
    printf 'ok=%s ko=%s detail=%s\n' \"\$PRETEST_OK\" \"\$PRETEST_KO\" \"\${PRETEST_LINES[*]}\"
    (( PRETEST_KO == 1 ))
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"raw mutating command found"* ]]
}
