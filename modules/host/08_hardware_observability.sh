#!/usr/bin/env bash
set -Eeuo pipefail

host_observability_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_observability_plan() {
  cat <<'EOF'
HOST HARDWARE OBSERVABILITY PLAN:
- install NVMe/SMART health tooling for system and DATA SSDs
- install temperature/sensor, PCI, USB and network diagnostics
- install V4L2 tools for webcam inventory and PipeWire/WirePlumber probes for audio
- install powertop for optional power diagnostics without applying automatic tuning
- collect a read-only health report after convergence
- never change firmware, SMART policy, fan curves, power profiles or device settings automatically
- every package mutation is executed only through run_mutating
EOF
}

host_observability_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    nvme-cli smartmontools lm-sensors lshw usbutils pciutils ethtool powertop v4l-utils \
    pipewire-bin wireplumber || return "$EXIT_APPLY_FAILED"
}

host_observability_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: hardware observability postcheck deferred'
    return 0
  fi

  local report="$REPORT_ROOT/$RUN_ID-host-hardware-health.txt"
  {
    printf '%s\n' '[nvme]'
    sudo nvme list 2>&1 || true
    printf '%s\n' '[smart]'
    sudo smartctl --scan-open 2>&1 || true
    printf '%s\n' '[sensors]'
    sensors 2>&1 || true
    printf '%s\n' '[pci]'
    lspci -nnk 2>&1 || true
    printf '%s\n' '[usb]'
    lsusb 2>&1 || true
    printf '%s\n' '[network]'
    ip -br link 2>&1 || true
    printf '%s\n' '[audio]'
    wpctl status 2>&1 || true
    pw-cli info 0 2>&1 || true
    printf '%s\n' '[video-devices]'
    v4l2-ctl --list-devices 2>&1 || true
  } > "$report"

  for cmd in nvme smartctl sensors lshw lsusb ethtool powertop v4l2-ctl wpctl pw-cli; do
    command -v "$cmd" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done
  [[ -s "$report" ]] || return "$EXIT_POSTCHECK_FAILED"
  log_info HOST "hardware health report=$report"
}
