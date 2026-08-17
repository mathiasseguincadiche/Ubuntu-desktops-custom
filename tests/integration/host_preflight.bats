#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  export HOST_PROBE_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/host"
  export REPORT_ROOT="$BATS_TEST_TMPDIR/reports"
  export RUN_ID='host-fixture'
  export HOST_RELEASE='26.04'
  export DATA_MOUNT='/data'
  export HARDWARE_MATCH_REQUIRED='true'
  mkdir -p "$REPORT_ROOT"
}

@test "HOST preflight accepts frozen workstation fixture" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    host_preflight_precheck
  "
  [ "$status" -eq 0 ]
}

@test "HOST preflight report inventories all critical domains" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    report=\$(host_preflight_collect)
    grep -F '[os-release]' \"\$report\"
    grep -F '[lscpu]' \"\$report\"
    grep -F '[lspci]' \"\$report\"
    grep -F '[lsblk]' \"\$report\"
    grep -F '[secure-boot]' \"\$report\"
    grep -F '[kvm]' \"\$report\"
    grep -F '[routes]' \"\$report\"
    grep -F '[dpkg-audit]' \"\$report\"
    grep -F '[package-manager-locks]' \"\$report\"
  "
  [ "$status" -eq 0 ]
}

@test "HOST preflight blocks an incomplete dpkg database" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    host_probe_dpkg_audit() { printf '%s\\n' 'package is only half configured'; }
    host_probe_package_manager_locks() { :; }
    host_preflight_assert_package_manager
  "
  [ "$status" -eq "$EXIT_PRECHECK_FAILED" ]
}

@test "HOST preflight blocks an actually held APT dpkg lock" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    host_probe_dpkg_audit() { :; }
    host_probe_package_manager_locks() { printf '%s\\n' '156160 apt-get /var/lib/dpkg/lock-frontend'; }
    host_preflight_assert_package_manager
  "
  [ "$status" -eq "$EXIT_PRECHECK_FAILED" ]
}

@test "HOST preflight does not block the normal unattended-upgrade shutdown waiter without locks" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    host_probe_dpkg_audit() { :; }
    host_probe_package_manager_locks() { :; }
    host_preflight_assert_package_manager
  "
  [ "$status" -eq 0 ]
}

@test "HOST preflight propagates a package-manager failure even when the phase caller uses if" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    export ACTIVE_SCOPE=HOST LOG_FILE='$BATS_TEST_TMPDIR/log.txt'
    source '$REPO_ROOT/modules/host/00_preflight.sh'
    host_probe_package_manager_locks() { printf '%s\\n' '156160 apt-get /var/lib/dpkg/lock-frontend'; }
    if host_preflight_precheck; then
      exit 99
    else
      exit \$?
    fi
  "
  [ "$status" -eq "$EXIT_PRECHECK_FAILED" ]
}

@test "HOST preflight no longer uses the unattended-upgrade process-name heuristic" {
  run grep -F '$3 == "unattended-upgr"' "$REPO_ROOT/modules/host/00_preflight.sh"
  [ "$status" -ne 0 ]
}

@test "HOST preflight is explicitly non-mutating" {
  run grep -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get|dnf|pacman|systemctl[[:space:]]+(enable|disable|start|stop|restart)|mount|umount|mkfs|parted|fdisk|nft|iptables)([[:space:]]|$)' "$REPO_ROOT/modules/host/00_preflight.sh"
  [ "$status" -ne 0 ]
}
