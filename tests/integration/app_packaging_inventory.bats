#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "packaging inventory detects duplicates and validates preferred source provenance" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
foo|managed|apt|foo|foo-snap|org.example.Foo|-|test apt preference
bar|managed|flatpak|bar|bar-snap|org.example.Bar|flathub|test flatpak preference
baz|preserve|snap|-|baz-snap|org.example.Baz|-|test preserve snap
qux|managed|vendor-apt|qux|qux-snap|org.example.Qux|vendor.example|test vendor apt
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='packaging-fixture'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"

    app_packaging_manager_summary() { printf '%s\\n' 'fixture'; }
    app_packaging_apt_installed() { [[ \"\$1\" == foo || \"\$1\" == qux ]]; }
    app_packaging_snap_installed() { [[ \"\$1\" == foo-snap || \"\$1\" == baz-snap ]]; }
    app_packaging_flatpak_installed() { [[ \"\$1\" == org.example.Bar ]]; }
    app_packaging_apt_origin_matches() { [[ \"\$2\" == vendor.example ]]; }
    app_packaging_flatpak_origin_matches() { [[ \"\$2\" == flathub ]]; }

    app_packaging_inventory_run
    cat \"\$APP_PACKAGING_REPORT\"
    printf 'duplicates=%s drift=%s conforming=%s preserved=%s planned=%s\\n' \
      \"\$APP_PACKAGING_DUPLICATES\" \"\$APP_PACKAGING_DRIFT\" \
      \"\$APP_PACKAGING_CONFORMING\" \"\$APP_PACKAGING_PRESERVED\" \"\$APP_PACKAGING_PLANNED\"
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"*"DUPLICATE"* ]]
  [[ "$output" == *"bar"*"flathub"*"CONFORMING"* ]]
  [[ "$output" == *"baz"*"PRESERVED"* ]]
  [[ "$output" == *"qux"*"vendor.example"*"CONFORMING"* ]]
  [[ "$output" == *"duplicates=1 drift=0 conforming=2 preserved=1 planned=0"* ]]
  [[ "$output" == *"READ-ONLY: no package, snap or flatpak was installed, removed, refreshed or migrated."* ]]
}

@test "packaging inventory reports alternative manager as drift and absent managed app as planned" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
foo|managed|apt|foo|foo-snap|org.example.Foo|-|test apt preference
bar|managed|flatpak|bar|bar-snap|org.example.Bar|flathub|test flatpak preference
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='packaging-drift'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"

    app_packaging_manager_summary() { printf '%s\\n' 'fixture'; }
    app_packaging_apt_installed() { return 1; }
    app_packaging_snap_installed() { [[ \"\$1\" == foo-snap ]]; }
    app_packaging_flatpak_installed() { return 1; }

    app_packaging_inventory_run
    cat \"\$APP_PACKAGING_REPORT\"
    printf 'duplicates=%s drift=%s planned=%s issue=%s\\n' \
      \"\$APP_PACKAGING_DUPLICATES\" \"\$APP_PACKAGING_DRIFT\" \"\$APP_PACKAGING_PLANNED\" \"\${APP_PACKAGING_ISSUES[*]}\"
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"*"DRIFT"* ]]
  [[ "$output" == *"bar"*"PLANNED"* ]]
  [[ "$output" == *"duplicates=0 drift=1 planned=1"* ]]
  [[ "$output" == *"foo=snap->apt"* ]]
}

@test "packaging inventory reports same manager with wrong vendor origin as drift" {
  cat > "$BATS_TEST_TMPDIR/policy.conf" <<'EOF'
qux|managed|vendor-apt|qux|-|-|vendor.example|test vendor apt
EOF

  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/app_packaging_inventory.sh'
    REPO_ROOT='$REPO_ROOT'
    REPORT_ROOT='$BATS_TEST_TMPDIR/reports'
    RUN_ID='packaging-origin-drift'
    APP_PACKAGING_POLICY_FILE='$BATS_TEST_TMPDIR/policy.conf'
    mkdir -p \"\$REPORT_ROOT\"

    app_packaging_manager_summary() { printf '%s\\n' 'fixture'; }
    app_packaging_apt_installed() { return 0; }
    app_packaging_snap_installed() { return 1; }
    app_packaging_flatpak_installed() { return 1; }
    app_packaging_apt_origin_matches() { return 1; }

    app_packaging_inventory_run
    cat \"\$APP_PACKAGING_REPORT\"
    printf 'drift=%s issue=%s\\n' \"\$APP_PACKAGING_DRIFT\" \"\${APP_PACKAGING_ISSUES[*]}\"
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"qux"*"MISMATCH"*"DRIFT"* ]]
  [[ "$output" == *"drift=1"* ]]
  [[ "$output" == *"qux=apt[source-mismatch]->vendor-apt"* ]]
}
