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

host_preflight_precheck() {
  assert_scope HOST
  host_preflight_assert_os
  host_preflight_assert_cpu
  host_preflight_assert_gpu
  host_preflight_assert_storage
  host_preflight_assert_kvm
  host_preflight_collect >/dev/null
  log_info HOST 'host preflight read-only checks passed'
}

host_preflight_plan() {
  printf '%s\n' 'READ-ONLY: validate Ubuntu release, Ryzen/SVM, Intel Arc presence, EXT4 system/data, /dev/kvm, Secure Boot and routes.'
}

host_preflight_apply() {
  # PRECHECK module has no mutating APPLY phase by design.
  log_info HOST 'host preflight apply is intentionally a no-op'
}

host_preflight_postcheck() {
  [[ -r "${HOST_PREFLIGHT_REPORT:-$REPORT_ROOT/$RUN_ID-host-preflight.txt}" ]] || return "$EXIT_POSTCHECK_FAILED"
}
