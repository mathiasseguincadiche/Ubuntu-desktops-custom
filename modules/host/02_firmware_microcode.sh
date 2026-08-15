#!/usr/bin/env bash
set -Eeuo pipefail

host_firmware_microcode_precheck() {
  assert_scope HOST
  command -v uname >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r /proc/cpuinfo ]] || return "$EXIT_PRECHECK_FAILED"
}

host_firmware_microcode_plan() {
  cat <<'EOF'
PLAN ONLY:
- verify AMD CPU microcode package availability
- verify linux-firmware state for motherboard/network/GPU devices
- inventory fwupd/LVFS capability when available
- do not flash firmware automatically without an explicit per-device policy
- report reboot requirement separately
EOF
}

host_firmware_microcode_apply() {
  log_info HOST 'firmware/microcode APPLY intentionally disabled during pre-test architecture phase'
}

host_firmware_microcode_postcheck() {
  [[ -r /proc/cpuinfo ]] || return "$EXIT_POSTCHECK_FAILED"
}
