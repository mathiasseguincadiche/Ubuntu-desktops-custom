#!/usr/bin/env bash
set -Eeuo pipefail

host_firmware_microcode_precheck() {
  assert_scope HOST
  command -v uname >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r /proc/cpuinfo ]] || return "$EXIT_PRECHECK_FAILED"
}

host_firmware_microcode_plan() {
  cat <<'EOF'
FIRMWARE / MICROCODE PLAN:
- install/refresh amd64-microcode for Ryzen 7 7700
- install/refresh linux-firmware for motherboard/network/GPU firmware payloads
- install fwupd for inventory/LVFS capability
- never flash device firmware automatically in this module
- firmware flashing requires a future per-device reviewed policy
- every package mutation is executed only through run_mutating
EOF
}

host_firmware_microcode_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install amd64-microcode linux-firmware fwupd || return "$EXIT_APPLY_FAILED"
}

host_firmware_microcode_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: firmware package postcheck deferred'
    return 0
  fi
  run_readonly HOST dpkg-query -W -f='${Status}\n' amd64-microcode linux-firmware fwupd >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  [[ -r /proc/cpuinfo ]] || return "$EXIT_POSTCHECK_FAILED"
}
