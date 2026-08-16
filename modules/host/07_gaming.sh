#!/usr/bin/env bash
set -Eeuo pipefail

host_gaming_precheck() {
  assert_scope HOST
  command -v lspci >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v dpkg >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/vendor/install_steam_repo.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

host_gaming_plan() {
  cat <<'EOF'
GAMING PLAN:
- enable i386 multiarch required by Steam runtime
- install Steam launcher from Valve's signed stable APT repository
- install 32-bit Mesa Vulkan/OpenGL runtime for Intel Arc compatibility from Ubuntu
- install GameMode, Gamescope and MangoHud/MangoApp for runtime control and performance observability
- validate Vulkan/OpenGL, VRR/Wayland readiness and controller support separately
- refuse an existing Ubuntu steam-installer package instead of silently replacing packaging provenance
- XeSS and frame generation remain game/runtime capabilities, never global forced toggles
- no unsupported kernel/graphics repository solely for gaming features
- every mutation is executed only through run_mutating
EOF
}

host_gaming_apply() {
  run_mutating HOST sudo dpkg --add-architecture i386 || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo apt-get update || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    gamemode gamescope mangohud mangoapp \
    libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386 || return "$EXIT_APPLY_FAILED"
  run_mutating HOST sudo bash "$REPO_ROOT/scripts/vendor/install_steam_repo.sh" || return "$EXIT_APPLY_FAILED"
}

host_gaming_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: gaming postcheck deferred'
    return 0
  fi
  dpkg --print-foreign-architectures | grep -Fxq i386 || return "$EXIT_POSTCHECK_FAILED"
  dpkg-query -W steam-launcher >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v gamemoderun >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v gamescope >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v mangohud >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
