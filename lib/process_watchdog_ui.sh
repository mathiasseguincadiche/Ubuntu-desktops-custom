#!/usr/bin/env bash

# Operator rendering for mutation watchdog events.
# Writes directly to /dev/tty because module stdout/stderr is intentionally
# redirected to modules.log in operator mode.

ui_live_watchdog_event() {
  local event="${1:?}" action="${2:-Configuration}" pid="${3:-?}" stat="${4:-?}" stopped_for="${5:-0}" command="${6:-}" detail="${7:-}"
  local headline status command_short elapsed=0 now

  declare -F ui_live_progress_enabled >/dev/null 2>&1 || return 0
  ui_live_progress_enabled || return 0
  [[ -w /dev/tty ]] 2>/dev/null || return 0

  command_short="${command//$'\n'/ }"
  if (( ${#command_short} > 132 )); then
    command_short="${command_short:0:129}..."
  fi

  case "$event" in
    SUSPENDED)
      headline='WATCHDOG — processus suspendu'
      status='WARN'
      ;;
    AUTO_CONTINUE)
      headline='WATCHDOG — reprise automatique SIGCONT'
      status='INFO'
      ;;
    RECOVERED)
      headline='WATCHDOG — processus repris'
      status='OK'
      ;;
    MANUAL_ACTION)
      headline='WATCHDOG — intervention opérateur requise'
      status='BLOCKED'
      ;;
    *)
      headline="WATCHDOG — $event"
      status='INFO'
      ;;
  esac

  # Clear the live action line, show the watchdog event, then redraw the action.
  printf '\r\033[2K' > /dev/tty
  printf '          ├─ %-47s %s\n' "$headline" "$(ui_status_text "$status")" > /dev/tty
  printf '             PID %s | état %s | suspendu %ss\n' "$pid" "$stat" "$stopped_for" > /dev/tty
  [[ -z "$command_short" ]] || printf '             Commande: %s\n' "$command_short" > /dev/tty
  [[ -z "$detail" ]] || printf '             Action: %s\n' "$detail" > /dev/tty

  if [[ -n "$action" ]]; then
    if [[ "${UI_LIVE_ACTION_STARTED_EPOCH:-0}" =~ ^[0-9]+$ ]] && (( UI_LIVE_ACTION_STARTED_EPOCH > 0 )); then
      now="$(date +%s)"
      elapsed=$((now - UI_LIVE_ACTION_STARTED_EPOCH))
      (( elapsed < 0 )) && elapsed=0
    fi
    ui_live_action_format "$action" RUNNING "$elapsed" > /dev/tty
    printf '\r' > /dev/tty
  fi
}
