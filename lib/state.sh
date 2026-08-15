#!/usr/bin/env bash

state_valid() {
  case "$1" in
    PENDING|RUNNING|SKIPPED|CHANGED|UNCHANGED|WARNING|FAILED|BLOCKED|REBOOT_REQUIRED|SUCCESS) return 0 ;;
    *) return 1 ;;
  esac
}

_json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

state_init() {
  : "${STATE_ROOT:?STATE_ROOT must be set}"
  : "${RUN_ID:?RUN_ID must be set}"
  RUN_STATE_DIR="$STATE_ROOT/runs/$RUN_ID"
  safe_mkdir "$RUN_STATE_DIR/modules"
  printf '{"run_id":"%s","created_at":"%s"}\n' \
    "$(_json_escape "$RUN_ID")" "$(_json_escape "$(uw_now)")" > "$RUN_STATE_DIR/run.json"
  printf '%s\n' "$RUN_ID" > "$STATE_ROOT/latest"
}

state_set() {
  local module="$1" state="$2" detail="${3:-}"
  state_valid "$state" || return "$EXIT_INVALID_ARGUMENT"
  : "${RUN_STATE_DIR:?state_init must be called first}"
  printf '{"module":"%s","state":"%s","detail":"%s","updated_at":"%s"}\n' \
    "$(_json_escape "$module")" "$(_json_escape "$state")" "$(_json_escape "$detail")" \
    "$(_json_escape "$(uw_now)")" > "$RUN_STATE_DIR/modules/$module.json"
}

state_get() {
  local module="$1" file
  : "${RUN_STATE_DIR:?RUN_STATE_DIR must be set}"
  file="$RUN_STATE_DIR/modules/$module.json"
  [[ -r "$file" ]] || return 1
  sed -nE 's/.*"state":"([A-Z_]+)".*/\1/p' "$file"
}

state_latest_run() {
  local file="$STATE_ROOT/latest"
  [[ -r "$file" ]] || return 1
  cat "$file"
}

state_resume_latest() {
  local latest
  latest="$(state_latest_run)" || return 1
  RUN_ID="$latest"
  RUN_STATE_DIR="$STATE_ROOT/runs/$RUN_ID"
  [[ -d "$RUN_STATE_DIR" ]]
}
