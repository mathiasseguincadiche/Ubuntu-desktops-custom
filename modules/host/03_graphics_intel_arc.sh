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
- install Mesa Vulkan/OpenGL diagnostics and Intel GEN8+ VA-API media driver
- validate kernel i915/xe support path appropriate for detected hardware after convergence
- validate Vulkan and VA-API userspace without forcing display settings
- validate Wayland/VRR/1440p/240 Hz separately after driver convergence
- treat XeSS/frame-generation support as game/runtime capability, not a global host switch
- every package mutation is executed only through run_mutating
EOF
}

host_graphics_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver || return "$EXIT_APPLY_FAILED"
}

host_graphics_postcheck() {
  command -v lspci >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: Intel Arc userspace postcheck deferred'
    return 0
  fi
  run_readonly HOST dpkg-query -W -f='${Status}\n' mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  command -v vulkaninfo >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
