#!/usr/bin/env bash
set -Eeuo pipefail

host_multimedia_precheck() {
  assert_scope HOST
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_multimedia_plan() {
  cat <<'EOF'
MULTIMEDIA / CODECS PLAN:
- install FFmpeg and VLC
- install GStreamer base/good/bad/ugly/libav plugin families
- preserve PipeWire/WirePlumber as the desktop audio stack
- validate Intel media acceleration separately through the graphics module
- avoid ubuntu-restricted-extras to prevent hidden interactive/EULA behavior in automation
- every package mutation is executed only through run_mutating
EOF
}

host_multimedia_apply() {
  run_mutating HOST sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ffmpeg vlc \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav pipewire wireplumber || return "$EXIT_APPLY_FAILED"
}

host_multimedia_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info HOST 'dry-run: multimedia postcheck deferred'
    return 0
  fi
  command -v ffmpeg >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  command -v vlc >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
