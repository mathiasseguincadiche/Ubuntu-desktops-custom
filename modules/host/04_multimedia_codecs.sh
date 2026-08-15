#!/usr/bin/env bash
set -Eeuo pipefail

host_multimedia_precheck() {
  assert_scope HOST
  command -v apt-cache >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_multimedia_plan() {
  cat <<'EOF'
PLAN ONLY:
- validate Ubuntu multimedia repository/component availability
- plan common audio/video codecs and GStreamer plugins
- validate FFmpeg/VLC capability
- validate Intel media acceleration integration when supported
- preserve PipeWire/WirePlumber as the desktop audio stack
- avoid replacing the desktop audio stack without an explicit compatibility reason
EOF
}

host_multimedia_apply() {
  log_info HOST 'multimedia/codecs APPLY intentionally disabled during pre-test architecture phase'
}

host_multimedia_postcheck() {
  command -v apt-cache >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
