#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "HOST module plan is ordered from preflight to validation" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    module_catalog_validate
    printf '%s\n' \"\${CATALOG_ORDER[@]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *$'host.preflight\nhost.os_updates\nhost.firmware_microcode\nhost.graphics\nhost.multimedia\nhost.apps\nhost.terminal\nhost.gaming\nhost.observability\nhost.validation'* ]]
}

@test "every HOST contract exposes four adapter functions" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/module_catalog.sh'
    REPO_ROOT='$REPO_ROOT'
    module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'
    for id in \"\${CATALOG_ORDER[@]}\"; do
      [[ \"\${CATALOG_SCOPE[\$id]}\" == HOST ]] || continue
      source \"$REPO_ROOT/\${CATALOG_PATH[\$id]}\"
      prefix=\"\${id//./_}\"
      declare -F \"\${prefix}_precheck\" >/dev/null
      declare -F \"\${prefix}_plan\" >/dev/null
      declare -F \"\${prefix}_apply\" >/dev/null
      declare -F \"\${prefix}_postcheck\" >/dev/null
    done
  "
  [ "$status" -eq 0 ]
}

@test "implemented HOST mutations use secure runner" {
  local file
  for file in \
    01_os_updates.sh \
    02_firmware_microcode.sh \
    03_graphics_intel_arc.sh \
    04_multimedia_codecs.sh \
    05_desktop_apps.sh \
    06_terminal_shell.sh \
    07_gaming.sh \
    08_hardware_observability.sh; do
    grep -F 'run_mutating HOST' "$REPO_ROOT/modules/host/$file"
  done
}

@test "HOST modules contain no raw package or service mutation bypass" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get)[[:space:]]+(install|upgrade|dist-upgrade|full-upgrade)|^[[:space:]]*(sudo[[:space:]]+)?systemctl[[:space:]]+(enable|disable|start|stop|restart)' "$REPO_ROOT/modules/host"
  [ "$status" -ne 0 ]
}

@test "graphics stack includes Intel Arc observability" {
  for token in vainfo intel-gpu-tools vulkaninfo; do
    grep -F "$token" "$REPO_ROOT/modules/host/03_graphics_intel_arc.sh"
  done
}

@test "gaming stack includes Gamescope and MangoHud" {
  for token in gamescope mangohud mangoapp gamemode; do
    grep -F "$token" "$REPO_ROOT/modules/host/07_gaming.sh"
  done
}

@test "hardware health stack covers storage sensors audio and webcam" {
  for token in nvme-cli smartmontools lm-sensors v4l-utils wpctl pw-cli; do
    grep -F "$token" "$REPO_ROOT/modules/host/08_hardware_observability.sh"
  done
}

@test "desktop apps keep MarkText stale upstream disabled by default" {
  grep -F 'MARKDOWN_EDITOR=ghostwriter' "$REPO_ROOT/config/applications.conf"
  grep -F 'MARKTEXT_AUTO_INSTALL=false' "$REPO_ROOT/config/applications.conf"
}

@test "DevOps tooling remains outside HOST contracts" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(docker|kubectl|terraform|ansible|aws|az)([[:space:]]|$)' "$REPO_ROOT/modules/host"
  [ "$status" -ne 0 ]
}
