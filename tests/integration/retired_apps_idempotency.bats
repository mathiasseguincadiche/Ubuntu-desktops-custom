#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/vendor/remove_retired_desktop_apps.sh"
}

@test "retired app cleanup reports already-absent states instead of forcing removals" {
  grep -F 'APT: $package déjà absent.' "$SCRIPT"
  grep -F 'Snap: $snap_name déjà absent.' "$SCRIPT"
  grep -F 'Flatpak système: $app_id déjà absent.' "$SCRIPT"
  grep -F 'Flatpak utilisateur: $app_id déjà absent.' "$SCRIPT"
}

@test "snap and flatpak inventory probes are time bounded" {
  grep -F 'timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" snap list' "$SCRIPT"
  grep -F 'timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" flatpak list --system' "$SCRIPT"
  grep -F 'timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" sudo -u "$desktop_user" flatpak list --user' "$SCRIPT"
}

@test "probe timeout fails closed instead of guessing package state" {
  grep -F 'refusing to guess package state' "$SCRIPT"
  grep -F 'retired_probe_fail Snap' "$SCRIPT"
  grep -F "retired_probe_fail 'Flatpak système'" "$SCRIPT"
}
