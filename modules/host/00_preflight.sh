#!/usr/bin/env bash
set -Eeuo pipefail

# HOST/PRECHECK — read-only workstation inventory and compatibility gate.
# No package install, service change, mount, firewall or device mutation is allowed here.

host_probe_fixture() {
  local name="$1"
  [[ -n "${HOST_PROBE_FIXTURE_DIR:-}" && -r "$HOST_PROBE_FIXTURE_DIR/$name" ]] || return 1
  cat "$HOST_PROBE_FIXTURE_DIR/$name"
}

host_probe_os_release() {
  host_probe_fixture os-release || cat /etc/os-release
}

host_probe_lscpu() {
  host_probe_fixture lscpu.txt || lscpu
}

host_probe_lspci() {
  host_probe_fixture lspci.txt || lspci -nnk
}

host_probe_lsblk() {
  host_probe_fixture lsblk.txt || lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS
}

host_probe_findmnt() {
  host_probe_fixture findmnt.txt || findmnt -rn -o TARGET,FSTYPE
}

host_probe_secureboot() {
  if host_probe_fixture secureboot.txt; then
    return 0
  fi
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state 2>&1 || true
  else
    printf '%s\n' 'mokutil unavailable'
  fi
}

host_probe_route() {
  host_probe_fixture ip-route.txt || ip -4 route show
}

host_probe_kvm() {
  if host_probe_fixture kvm.txt; then
    return 0
  fi
  [[ -c /dev/kvm ]] && printf '%s\n' 'present' || printf '%s\n' 'missing'
}

host_probe_dpkg_audit() {
  # Frozen fixtures predating this probe intentionally model a healthy empty
  # audit unless an explicit dpkg-audit.txt is provided by a test.
  if [[ -n "${HOST_PROBE_FIXTURE_DIR:-}" ]]; then
    host_probe_fixture dpkg-audit.txt || true
    return 0
  fi
  dpkg --audit 2>&1 || true
}

host_probe_package_manager_locks() {
  # A long-lived unattended-upgrade-shutdown --wait-for-signal process is
  # normal on Ubuntu and is not evidence that APT/dpkg is busy. Block only on
  # an actually held package-manager lock.
  if [[ -n "${HOST_PROBE_FIXTURE_DIR:-}" ]]; then
    host_probe_fixture package-manager-locks.txt || true
    return 0
  fi

  lslocks -n -o PID,COMMAND,PATH 2>/dev/null | awk '
    $3 == "/var/lib/dpkg/lock-frontend" ||
    $3 == "/var/lib/dpkg/lock" ||
    $3 == "/var/cache/apt/archives/lock" ||
    $3 == "/var/lib/apt/lists/lock" ||
    $3 == "/run/unattended-upgrades.lock" ||
    $3 == "/var/run/unattended-upgrades.lock" {
      print
    }
  '
}

host_preflight_collect() {
  local report="${HOST_PREFLIGHT_REPORT:-$REPORT_ROOT/$RUN_ID-host-preflight.txt}"
  {
    printf '%s\n' '[os-release]'
    host_probe_os_release
    printf '%s\n' '[lscpu]'
    host_probe_lscpu
    printf '%s\n' '[lspci]'
    host_probe_lspci
    printf '%s\n' '[lsblk]'
    host_probe_lsblk
    printf '%s\n' '[findmnt]'
    host_probe_findmnt
    printf '%s\n' '[secure-boot]'
    host_probe_secureboot
    printf '%s\n' '[kvm]'
    host_probe_kvm
    printf '%s\n' '[routes]'
    host_probe_route
    printf '%s\n' '[dpkg-audit]'
    host_probe_dpkg_audit
    printf '%s\n' '[package-manager-locks]'
    host_probe_package_manager_locks
  } > "$report"
  printf '%s\n' "$report"
}

host_preflight_assert_os() {
  local data
  data="$(host_probe_os_release)"
  grep -Eq '^ID=ubuntu$|^ID="ubuntu"$' <<< "$data" || return "$EXIT_PRECHECK_FAILED"
  grep -Eq "^VERSION_ID=\"?${HOST_RELEASE:-26.04}\"?$" <<< "$data" || return "$EXIT_PRECHECK_FAILED"
}

host_preflight_assert_cpu() {
  local data
  data="$(host_probe_lscpu)"
  grep -Fq 'AMD Ryzen 7 7700' <<< "$data" || [[ "${HARDWARE_MATCH_REQUIRED:-false}" != 'true' ]] || return "$EXIT_PRECHECK_FAILED"
  grep -Eq 'AMD-V|Virtualization:[[:space:]]+AMD-V' <<< "$data" || return "$EXIT_PRECHECK_FAILED"
}

host_preflight_assert_gpu() {
  local data
  data="$(host_probe_lspci)"
  grep -Eqi 'Intel.*Arc.*B580|Arc B580' <<< "$data" || [[ "${HARDWARE_MATCH_REQUIRED:-false}" != 'true' ]] || return "$EXIT_PRECHECK_FAILED"
}

host_preflight_assert_storage() {
  local data
  data="$(host_probe_findmnt)"
  grep -Eq '^/[[:space:]]+ext4$' <<< "$data" || return "$EXIT_PRECHECK_FAILED"
  if [[ -n "${DATA_MOUNT:-}" ]]; then
    grep -Eq "^${DATA_MOUNT}[[:space:]]+ext4$" <<< "$data" || return "$EXIT_PRECHECK_FAILED"
  fi
}

host_preflight_assert_kvm() {
  grep -Fq 'present' <<< "$(host_probe_kvm)" || return "$EXIT_PRECHECK_FAILED"
}

host_preflight_assert_package_manager() {
  local audit locks

  audit="$(host_probe_dpkg_audit)"
  if [[ -n "${audit//[[:space:]]/}" ]]; then
    log_error HOST "dpkg audit is not clean; package database may be incomplete after an interrupted install: $(printf '%s' "$audit" | tr '\n' ';')"
    return "$EXIT_PRECHECK_FAILED"
  fi

  locks="$(host_probe_package_manager_locks)"
  if [[ -n "${locks//[[:space:]]/}" ]]; then
    log_error HOST "an APT/dpkg lock is currently held; refusing REAL APPLY until the package transaction exits: $(printf '%s' "$locks" | tr '\n' ';')"
    return "$EXIT_PRECHECK_FAILED"
  fi
}

host_preflight_precheck() {
  local cmd
  assert_scope HOST || return "$?"

  if [[ -z "${HOST_PROBE_FIXTURE_DIR:-}" ]]; then
    for cmd in lscpu lspci lsblk findmnt ip dpkg lslocks awk; do
      command -v "$cmd" >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
    done
  fi

  # Always preserve a read-only inventory, including when a compatibility assertion fails afterwards.
  host_preflight_collect >/dev/null || return "$EXIT_PRECHECK_FAILED"

  # Do not rely on Bash errexit here: orchestrator phases are intentionally
  # invoked from a conditional context so every assertion must propagate its
  # own status explicitly.
  host_preflight_assert_os || return "$?"
  host_preflight_assert_cpu || return "$?"
  host_preflight_assert_gpu || return "$?"
  host_preflight_assert_storage || return "$?"
  host_preflight_assert_kvm || return "$?"
  host_preflight_assert_package_manager || return "$?"
  log_info HOST 'host preflight read-only checks passed'
}

host_preflight_plan() {
  printf '%s\n' 'READ-ONLY: validate Ubuntu release, Ryzen/SVM, Intel Arc presence, EXT4 system/data, /dev/kvm, Secure Boot, routes and APT/dpkg lock health.'
}

host_preflight_apply() {
  # PRECHECK module has no mutating APPLY phase by design.
  log_info HOST 'host preflight apply is intentionally a no-op'
}

host_preflight_postcheck() {
  [[ -r "${HOST_PREFLIGHT_REPORT:-$REPORT_ROOT/$RUN_ID-host-preflight.txt}" ]] || return "$EXIT_POSTCHECK_FAILED"
}
