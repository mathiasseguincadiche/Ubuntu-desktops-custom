#!/usr/bin/env bash
set -Eeuo pipefail

host_graphics_precheck() {
  assert_scope HOST
  command -v lspci >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  lspci | grep -Eqi 'Intel.*(Arc|VGA|Display)' || [[ "${HARDWARE_MATCH_REQUIRED:-false}" != 'true' ]] || return "$EXIT_PRECHECK_FAILED"
}

host_graphics_plan() {
  cat <<'EOF'
INTEL ARC B580 GRAPHICS PLAN:
- use Ubuntu 26.04 distribution kernel/firmware and Mesa stack; no third-party GPU repository by default
- install Vulkan/OpenGL diagnostics, Intel media VA-API support, vainfo and intel-gpu-tools
- validate kernel driver binding, Vulkan device visibility and VA-API capabilities after convergence
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
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: Intel Arc userspace postcheck deferred'
    return 0
  fi

  run_readonly HOST dpkg-query -W -f='${Status}\n' \
    mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver vainfo intel-gpu-tools >/dev/null \
    || return "$EXIT_POSTCHECK_FAILED"
  lspci -nnk | grep -A3 -Eqi 'Intel.*Arc.*B580|Arc B580' || return "$EXIT_POSTCHECK_FAILED"
  command -v vulkaninfo >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v vainfo >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  run_readonly HOST vulkaninfo --summary >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  if ! run_readonly HOST vainfo >/dev/null 2>&1; then
    log_warn HOST 'VA-API runtime probe did not succeed in the current session; inspect display/session permissions.'
  fi
  if [[ "${XDG_SESSION_TYPE:-unknown}" != wayland ]]; then
    log_warn HOST "current desktop session is ${XDG_SESSION_TYPE:-unknown}; Wayland/VRR runtime validation remains pending"
  fi
}
