#!/usr/bin/env bash
set -Eeuo pipefail

host_gaming_precheck() {
  assert_scope HOST
  command -v lspci >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_gaming_plan() {
  cat <<'EOF'
PLAN ONLY:
- Steam client and 32-bit graphics/runtime prerequisites
- Vulkan/OpenGL validation for Intel Arc B580
- VRR/Wayland readiness and controller support
- GameMode/MangoHud-class tooling only when compatible and useful
- XeSS capability comes from supported games/runtime; do not fake driver-level toggles
- multi-frame-generation capability must be treated as game/runtime specific, not globally forced
- no unsupported kernel/graphics repository solely for gaming features
EOF
}

host_gaming_apply() {
  log_info HOST 'gaming APPLY intentionally disabled during pre-test architecture phase'
}

host_gaming_postcheck() {
  command -v lspci >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
