#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "pre-apply packaging gate blocks drift before any mutation" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
foo|managed|apt|foo|foo-snap|org.example.Foo|-|test
bar|managed|flatpak|bar|-|org.example.Bar|flathub|test
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='preapply-block'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"
    app_packaging_manager_summary() { printf '%s\\n' fixture; }
    app_packaging_apt_installed() { return 1; }
    app_packaging_snap_installed() { [[ \"\$1\" == foo-snap ]]; }
    app_packaging_flatpak_installed() { return 1; }
    app_packaging_require_preapply_clean
  "

  [ "$status" -eq 8 ]
  [[ "$output" == *"REAL APPLY blocked"* ]]
  [[ "$output" == *"foo=snap->apt"* ]]
  [ -f "$BATS_TEST_TMPDIR/reports/preapply-block-preapply-app-packaging-inventory.txt" ]
}

@test "pre-apply packaging gate allows absent planned applications" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
foo|managed|apt|foo|-|-|-|test
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='preapply-planned'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"
    app_packaging_manager_summary() { printf '%s\\n' fixture; }
    app_packaging_apt_installed() { return 1; }
    app_packaging_snap_installed() { return 1; }
    app_packaging_flatpak_installed() { return 1; }
    app_packaging_require_preapply_clean
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"planned=1 | drift=0 | duplicates=0"* ]]
}

@test "post-HOST packaging gate rejects planned drift or duplicates" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
foo|managed|apt|foo|-|-|-|test
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='posthost-incomplete'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"
    app_packaging_manager_summary() { printf '%s\\n' fixture; }
    app_packaging_apt_installed() { return 1; }
    app_packaging_snap_installed() { return 1; }
    app_packaging_flatpak_installed() { return 1; }
    app_packaging_require_posthost_converged
  "

  [ "$status" -eq 6 ]
  [[ "$output" == *"HOST packaging convergence incomplete"* ]]
}

@test "real apply contract checks packaging before runtime and after HOST" {
  grep -Fq 'app_packaging_require_preapply_clean' "$REPO_ROOT/lib/apply_gate.sh"
  grep -Fq 'REAL_APPLY_REQUIRE_CLEAN_APP_PACKAGING' "$REPO_ROOT/config/apply-gate.conf"
  grep -Fq 'app_packaging_require_posthost_converged' "$REPO_ROOT/install.sh"
  grep -Fq 'REAL_APPLY_VERIFY_APP_PACKAGING_AFTER_HOST' "$REPO_ROOT/config/apply-gate.conf"
}
