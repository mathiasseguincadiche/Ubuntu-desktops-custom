#!/usr/bin/env bash
set -Eeuo pipefail

host_graphics_normalize_hex_id() {
  local value="${1,,}"
  value="${value#0x}"
  printf '%s\n' "$value"
}

host_graphics_expected_pci_device_path() {
  local root="${GPU_SYSFS_ROOT:-/sys/bus/pci/devices}"
  local expected_vendor expected_device expected_driver
  local dev class vendor device driver

  expected_vendor="$(host_graphics_normalize_hex_id "${EXPECTED_GPU_PCI_VENDOR:-8086}")"
  expected_device="$(host_graphics_normalize_hex_id "${EXPECTED_GPU_PCI_DEVICE:-e20b}")"
  expected_driver="${EXPECTED_GPU_KERNEL_DRIVER:-xe}"

  [[ -d "$root" ]] || return 1

  for dev in "$root"/*; do
    [[ -d "$dev" && -r "$dev/class" && -r "$dev/vendor" && -r "$dev/device" ]] || continue

    class="$(<"$dev/class")"
    [[ "${class,,}" == 0x03* ]] || continue

    vendor="$(host_graphics_normalize_hex_id "$(<"$dev/vendor")")"
    device="$(host_graphics_normalize_hex_id "$(<"$dev/device")")"
    [[ "$vendor" == "$expected_vendor" && "$device" == "$expected_device" ]] || continue

    [[ -L "$dev/driver" ]] || return 1
    driver="$(basename "$(readlink -f "$dev/driver")")"
    [[ "$driver" == "$expected_driver" ]] || return 1

    printf '%s\n' "$dev"
    return 0
  done

  return 1
}

host_graphics_vulkan_summary_matches_expected() {
  local summary="$1"
  local expected_vendor expected_device

  expected_vendor="0x$(host_graphics_normalize_hex_id "${EXPECTED_GPU_PCI_VENDOR:-8086}")"
  expected_device="0x$(host_graphics_normalize_hex_id "${EXPECTED_GPU_PCI_DEVICE:-e20b}")"

  awk -v vendor="${expected_vendor,,}" -v device="${expected_device,,}" '
    function reset_gpu() {
      have_vendor = 0
      have_device = 0
      have_discrete = 0
      have_intel_mesa = 0
    }
    function current_gpu_matches() {
      return have_vendor && have_device && have_discrete && have_intel_mesa
    }
    BEGIN {
      in_gpu = 0
      matched = 0
      reset_gpu()
    }
    /^GPU[0-9]+:/ {
      if (in_gpu && current_gpu_matches()) {
        matched = 1
      }
      in_gpu = 1
      reset_gpu()
      next
    }
    in_gpu {
      line = tolower($0)
      if (line ~ "vendorid[[:space:]]*=[[:space:]]*" vendor "([[:space:]]|$)") {
        have_vendor = 1
      }
      if (line ~ "deviceid[[:space:]]*=[[:space:]]*" device "([[:space:]]|$)") {
        have_device = 1
      }
      if (line ~ /devicetype[[:space:]]*=[[:space:]]*physical_device_type_discrete_gpu/) {
        have_discrete = 1
      }
      if (line ~ /driverid[[:space:]]*=[[:space:]]*driver_id_intel_open_source_mesa/) {
        have_intel_mesa = 1
      }
    }
    END {
      if (in_gpu && current_gpu_matches()) {
        matched = 1
      }
      exit(matched ? 0 : 1)
    }
  ' <<< "$summary"
}

host_graphics_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"

  if is_true "${HARDWARE_MATCH_REQUIRED:-false}"; then
    host_graphics_expected_pci_device_path >/dev/null || return "$EXIT_PRECHECK_FAILED"
  fi
}

host_graphics_plan() {
  cat <<'EOF'
INTEL ARC B580 GRAPHICS PLAN:
- use Ubuntu 26.04 distribution kernel/firmware and Mesa stack; no third-party GPU repository by default
- install Vulkan/OpenGL diagnostics, Intel media VA-API support, vainfo and intel-gpu-tools
- validate the Arc B580 by exact PCI identity 8086:e20b and xe kernel-driver binding
- validate Vulkan visibility through the Intel open-source Mesa driver after convergence
- inventory AV1/HEVC/H264 hardware decode capabilities when exposed by the media stack
- report Wayland session state; display VRR/refresh configuration remains non-destructive and operator-visible
- treat XeSS/frame-generation support as game/runtime capability, not a global host switch
- every package mutation is executed only through run_mutating
EOF
}

host_graphics_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver \
    vainfo intel-gpu-tools || return "$EXIT_APPLY_FAILED"
}

host_graphics_postcheck() {
  local gpu_sysfs vulkan_summary

  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: Intel Arc userspace postcheck deferred'
    return 0
  fi

  run_readonly HOST dpkg-query -W -f='${Status}\n' \
    mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver vainfo intel-gpu-tools >/dev/null \
    || return "$EXIT_POSTCHECK_FAILED"

  gpu_sysfs="$(host_graphics_expected_pci_device_path)" || return "$EXIT_POSTCHECK_FAILED"
  log_info HOST "Intel Arc B580 PCI identity and kernel binding validated at ${gpu_sysfs##*/}"

  command -v vulkaninfo >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v vainfo >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"

  vulkan_summary="$(run_readonly HOST vulkaninfo --summary)" || return "$EXIT_POSTCHECK_FAILED"
  host_graphics_vulkan_summary_matches_expected "$vulkan_summary" || return "$EXIT_POSTCHECK_FAILED"
  log_info HOST 'Intel Arc B580 Vulkan device validated through the Intel open-source Mesa driver'

  if ! run_readonly HOST vainfo >/dev/null 2>&1; then
    log_warn HOST 'VA-API runtime probe did not succeed in the current session; inspect display/session permissions.'
  fi
  if [[ "${XDG_SESSION_TYPE:-unknown}" != wayland ]]; then
    log_warn HOST "current desktop session is ${XDG_SESSION_TYPE:-unknown}; Wayland/VRR runtime validation remains pending"
  fi
}
