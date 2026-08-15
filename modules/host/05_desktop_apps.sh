#!/usr/bin/env bash
set -Eeuo pipefail

host_apps_precheck() {
  assert_scope HOST
  command -v apt-cache >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

host_apps_plan() {
  cat <<'EOF'
PLAN ONLY:
- VS Code with Remote SSH support for KVM guests
- PDF editor, OBS Studio, FileZilla, MarkText/Markdown editor, draw.io
- Brave Browser, Bitwarden, VLC, Remmina
- OnlyOffice and LibreOffice
- enhanced Nautilus integration/extensions where compatible with Ubuntu 26.04
- prefer vendor/Ubuntu-supported repositories and sandboxed packaging only when justified
- verify desktop integration after each application family
EOF
}

host_apps_apply() {
  log_info HOST 'desktop applications APPLY intentionally disabled during pre-test architecture phase'
}

host_apps_postcheck() {
  command -v apt-cache >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
