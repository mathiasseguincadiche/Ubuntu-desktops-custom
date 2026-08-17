#!/usr/bin/env bash

# Runtime watchdog for REAL APPLY mutations.
#
# A mutating command is still executed synchronously by runner.sh. This watchdog
# runs beside it and inspects only descendants of the current runner shell. It
# never kills a package manager. A job-control stopped process (ps STAT=T/T+)
# is reported after a short grace period and may receive one bounded SIGCONT.
# If automatic recovery is unavailable or the same PID stops again, execution
# remains fail-closed: the command stays stopped and an explicit operator action
# is displayed instead of silently waiting forever.

PROCESS_WATCHDOG_PID=''

process_watchdog_enabled() {
  is_true "${MUTATION_WATCHDOG_ENABLED:-true}" || return 1
  command -v ps >/dev/null 2>&1 || return 1
  command -v awk >/dev/null 2>&1 || return 1
  command -v kill >/dev/null 2>&1 || return 1
}

process_watchdog_positive_integer() {
  local value="${1:-}" fallback="${2:?}"
  if [[ "$value" =~ ^[0-9]+$ ]] && (( 10#$value > 0 )); then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

process_watchdog_descendants_snapshot() {
  local root_pid="${1:?}" excluded_pid="${2:?}"

  ps -eo pid=,ppid=,stat=,args= 2>/dev/null | awk \
    -v root="$root_pid" -v excluded_root="$excluded_pid" '
      {
        pid=$1
        parent=$2
        stat=$3
        $1=$2=$3=""
        sub(/^[[:space:]]+/, "", $0)
        parent_of[pid]=parent
        stat_of[pid]=stat
        args_of[pid]=$0
        order[++count]=pid
      }
      END {
        descendant[root]=1
        excluded[excluded_root]=1

        changed=1
        while (changed) {
          changed=0
          for (i=1; i<=count; i++) {
            pid=order[i]
            parent=parent_of[pid]
            if (!descendant[pid] && descendant[parent]) {
              descendant[pid]=1
              changed=1
            }
            if (!excluded[pid] && excluded[parent]) {
              excluded[pid]=1
              changed=1
            }
          }
        }

        for (i=1; i<=count; i++) {
          pid=order[i]
          if (pid != root && descendant[pid] && !excluded[pid]) {
            printf "%s\t%s\t%s\n", pid, stat_of[pid], args_of[pid]
          }
        }
      }
    '
}

process_watchdog_log_file() {
  [[ -n "${LOG_DIR:-}" ]] || return 1
  printf '%s/process-watchdog.log\n' "$LOG_DIR"
}

process_watchdog_status_file() {
  [[ -n "${RUN_STATE_DIR:-}" ]] || return 1
  printf '%s/process-watchdog.status\n' "$RUN_STATE_DIR"
}

process_watchdog_sanitize_line() {
  local value="$*"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  printf '%s' "$value"
}

process_watchdog_write_status() {
  local state="${1:?}" scope="${2:?}" action="${3:-}" pid="${4:-}" stat="${5:-}" stopped_for="${6:-0}" command="${7:-}" detail="${8:-}"
  local status_file tmp

  status_file="$(process_watchdog_status_file 2>/dev/null || true)"
  [[ -n "$status_file" ]] || return 0
  safe_mkdir "$(dirname "$status_file")"
  tmp="${status_file}.tmp.${BASHPID:-$$}"

  {
    printf 'state=%s\n' "$(process_watchdog_sanitize_line "$state")"
    printf 'scope=%s\n' "$(process_watchdog_sanitize_line "$scope")"
    printf 'action=%s\n' "$(process_watchdog_sanitize_line "$action")"
    printf 'pid=%s\n' "$(process_watchdog_sanitize_line "$pid")"
    printf 'stat=%s\n' "$(process_watchdog_sanitize_line "$stat")"
    printf 'stopped_for_seconds=%s\n' "$(process_watchdog_sanitize_line "$stopped_for")"
    printf 'command=%s\n' "$(process_watchdog_sanitize_line "$command")"
    printf 'detail=%s\n' "$(process_watchdog_sanitize_line "$detail")"
    printf 'updated_at=%s\n' "$(uw_now)"
  } > "$tmp"
  mv -f -- "$tmp" "$status_file"
}

process_watchdog_report() {
  local event="${1:?}" scope="${2:?}" action="${3:-}" pid="${4:-}" stat="${5:-}" stopped_for="${6:-0}" command="${7:-}" detail="${8:-}"
  local log_file message

  command="$(process_watchdog_sanitize_line "$command")"
  action="$(process_watchdog_sanitize_line "$action")"
  detail="$(process_watchdog_sanitize_line "$detail")"
  message="MUTATION_WATCHDOG event=$event scope=$scope action=$action pid=$pid stat=$stat stopped_for=${stopped_for}s command=$command detail=$detail"

  log_file="$(process_watchdog_log_file 2>/dev/null || true)"
  if [[ -n "$log_file" ]]; then
    printf '%s %s\n' "$(uw_now)" "$message" >> "$log_file"
  fi

  case "$event" in
    SUSPENDED|MANUAL_ACTION)
      log_warn ENGINE "$message"
      ;;
    *)
      log_info ENGINE "$message"
      ;;
  esac

  process_watchdog_write_status "$event" "$scope" "$action" "$pid" "$stat" "$stopped_for" "$command" "$detail"

  if declare -F ui_live_watchdog_event >/dev/null 2>&1; then
    ui_live_watchdog_event "$event" "$action" "$pid" "$stat" "$stopped_for" "$command" "$detail"
  fi
}

process_watchdog_continue_pid() {
  local pid="${1:?}"

  if kill -CONT "$pid" 2>/dev/null; then
    return 0
  fi

  # Root-owned descendants are common because run_mutating launches sudo.
  # -n is mandatory: the watchdog must never open a hidden password prompt.
  if command -v sudo >/dev/null 2>&1 && sudo -n kill -CONT "$pid" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

process_watchdog_monitor() {
  local root_pid="${1:?}" scope="${2:?}" action="${3:-Configuration}" self_pid
  local poll_seconds stop_grace_seconds max_auto_continues now pid stat command stopped_for attempts_count
  local auto_continue="${MUTATION_WATCHDOG_AUTO_CONTINUE:-true}"
  declare -A stopped_since=()
  declare -A continue_attempts=()
  declare -A warned=()
  declare -A manual_reported=()
  declare -A currently_stopped=()

  self_pid="${BASHPID:-$$}"
  poll_seconds="$(process_watchdog_positive_integer "${MUTATION_WATCHDOG_POLL_SECONDS:-1}" 1)"
  stop_grace_seconds="$(process_watchdog_positive_integer "${MUTATION_WATCHDOG_STOP_GRACE_SECONDS:-5}" 5)"
  max_auto_continues="$(process_watchdog_positive_integer "${MUTATION_WATCHDOG_MAX_AUTO_CONTINUES:-1}" 1)"

  trap 'exit 0' TERM INT HUP

  while kill -0 "$root_pid" 2>/dev/null; do
    now="$(date +%s)"
    currently_stopped=()

    while IFS=$'\t' read -r pid stat command; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      [[ "$stat" == T* ]] || continue

      currently_stopped["$pid"]=1
      if [[ -z "${stopped_since[$pid]+x}" ]]; then
        stopped_since["$pid"]="$now"
      fi
      stopped_for=$((now - stopped_since[$pid]))
      (( stopped_for >= stop_grace_seconds )) || continue

      if [[ "${warned[$pid]:-false}" != true ]]; then
        process_watchdog_report SUSPENDED "$scope" "$action" "$pid" "$stat" "$stopped_for" "$command" \
          'Processus enfant suspendu par job-control; la mutation ne progresse plus.'
        warned["$pid"]=true
      fi

      attempts_count="${continue_attempts[$pid]:-0}"
      if is_true "$auto_continue" && (( attempts_count < max_auto_continues )); then
        attempts_count=$((attempts_count + 1))
        continue_attempts["$pid"]="$attempts_count"
        if process_watchdog_continue_pid "$pid"; then
          process_watchdog_report AUTO_CONTINUE "$scope" "$action" "$pid" "$stat" "$stopped_for" "$command" \
            "SIGCONT automatique envoyé (tentative ${attempts_count}/${max_auto_continues})."
          # A fresh grace period prevents a tight SIGCONT loop if the process is
          # immediately stopped again.
          stopped_since["$pid"]="$now"
          warned["$pid"]=false
        else
          continue_attempts["$pid"]="$max_auto_continues"
          manual_reported["$pid"]=true
          process_watchdog_report MANUAL_ACTION "$scope" "$action" "$pid" "$stat" "$stopped_for" "$command" \
            "Reprise automatique impossible sans élévation non interactive; exécuter: sudo kill -CONT $pid"
        fi
      elif [[ "${manual_reported[$pid]:-false}" != true ]]; then
        manual_reported["$pid"]=true
        process_watchdog_report MANUAL_ACTION "$scope" "$action" "$pid" "$stat" "$stopped_for" "$command" \
          "Processus toujours suspendu après ${attempts_count} reprise(s); intervention opérateur requise: sudo kill -CONT $pid"
      fi
    done < <(process_watchdog_descendants_snapshot "$root_pid" "$self_pid")

    for pid in "${!stopped_since[@]}"; do
      if [[ -z "${currently_stopped[$pid]+x}" ]]; then
        if (( ${continue_attempts[$pid]:-0} > 0 )); then
          process_watchdog_report RECOVERED "$scope" "$action" "$pid" RUNNING 0 '' \
            'Le processus n’est plus suspendu; la mutation peut continuer.'
        fi
        unset 'stopped_since[$pid]' 'continue_attempts[$pid]' 'warned[$pid]' 'manual_reported[$pid]'
      fi
    done

    sleep "$poll_seconds"
  done
}

process_watchdog_start() {
  local root_pid="${1:?}" scope="${2:?}" action="${3:-Configuration}"
  PROCESS_WATCHDOG_PID=''
  process_watchdog_enabled || return 0

  process_watchdog_monitor "$root_pid" "$scope" "$action" &
  PROCESS_WATCHDOG_PID=$!
}

process_watchdog_stop() {
  local pid="${1:-${PROCESS_WATCHDOG_PID:-}}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0

  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [[ "${PROCESS_WATCHDOG_PID:-}" == "$pid" ]]; then
    PROCESS_WATCHDOG_PID=''
  fi
}
