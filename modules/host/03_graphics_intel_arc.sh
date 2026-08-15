#!/usr/bin/env bash
set -Eeuo pipefail

host_graphics_precheck() {
  assert_scope HOST
  command -v lspci >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  lspci | grep -Eqi 'Intel.*(Arc|VGA|Display)' || [[ "${HARDWARE_MATCH_REQUIRED:-false}" != 'true' ]] || return "$EXIT_PRECHECK_FAILED"
}

host_graphics_plan() {
  cat <<'EOF'
PLAN ONLY:
- validate kernel i915/xe support path appropriate for Intel Arc B580
- validate Mesa/Vulkan/OpenGL userspace stack
- validate VA-API/media acceleration stack
- validate Wayland, VRR and 1440p/240 Hz capability without forcing display settings
- inventory XeSS/game dependencies separately from host graphics driver state
- no third-party GPU repository unless explicitly justified and tested
EOF
}

host_graphics_apply() {
  log_info HOST 'Intel Arc graphics APPLY intentionally disabled during pre-test architecture phase'
}

host_graphics_postcheck() {
  command -v lspci >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
