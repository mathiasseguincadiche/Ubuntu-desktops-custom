#!/usr/bin/env bash

# Registry consumed through sourcing; associative arrays require Bash 4+.
declare -Ag ORCH_SCOPE=()
declare -Ag ORCH_DEPS=()
declare -Ag ORCH_PRECHECK=()
declare -Ag ORCH_PLAN=()
declare -Ag ORCH_APPLY=()
declare -Ag ORCH_POSTCHECK=()
declare -ag ORCH_ORDER=()

orchestrator_reset() {
  ORCH_SCOPE=()
  ORCH_DEPS=()
  ORCH_PRECHECK=()
  ORCH_PLAN=()
  ORCH_APPLY=()
  ORCH_POSTCHECK=()
  ORCH_ORDER=()
}

orchestrator_register() {
  local id="$1" scope="$2" deps="${3:-}" precheck_fn="${4:-}" plan_fn="${5:-}" apply_fn="${6:-}" postcheck_fn="${7:-}"
  [[ "$id" =~ ^[A-Za-z0-9_.-]+$ ]] || return "$EXIT_INVALID_ARGUMENT"
  scope_valid "$scope" || return "$EXIT_INVALID_ARGUMENT"
  [[ -z "${ORCH_SCOPE[$id]+x}" ]] || return "$EXIT_INVALID_ARGUMENT"

  ORCH_SCOPE["$id"]="$scope"
  ORCH_DEPS["$id"]="$deps"
  ORCH_PRECHECK["$id"]="$precheck_fn"
  ORCH_PLAN["$id"]="$plan_fn"
  ORCH_APPLY["$id"]="$apply_fn"
  ORCH_POSTCHECK["$id"]="$postcheck_fn"
  ORCH_ORDER+=("$id")
}

orchestrator_call() {
  local fn="$1"
  [[ -z "$fn" ]] && return 0
  declare -F "$fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"
  "$fn"
}

orchestrator_state_satisfies_dependency() {
  case "$1" in
    SUCCESS|UNCHANGED|CHANGED|SKIPPED) return 0 ;;
    *) return 1 ;;
  esac
}

orchestrator_dependencies_ready() {
  local id="$1" dep dep_state
  for dep in ${ORCH_DEPS[$id]:-}; do
    [[ -n "${ORCH_SCOPE[$dep]+x}" ]] || return "$EXIT_DEPENDENCY_FAILED"
    dep_state="$(state_get "$dep" 2>/dev/null || true)"
    orchestrator_state_satisfies_dependency "$dep_state" || return "$EXIT_DEPENDENCY_FAILED"
  done
}

orchestrator_should_resume_skip() {
  local id="$1" current
  [[ "${ORCH_RESUME:-false}" == 'true' ]] || return 1
  current="$(state_get "$id" 2>/dev/null || true)"
  orchestrator_state_satisfies_dependency "$current"
}

orchestrator_run_module() {
  local id="$1" previous_scope="${ACTIVE_SCOPE:-}" rc=0
  [[ -n "${ORCH_SCOPE[$id]+x}" ]] || return "$EXIT_INVALID_ARGUMENT"

  if orchestrator_should_resume_skip "$id"; then
    log_info ENGINE "resume skip module=$id state=$(state_get "$id")"
    return 0
  fi

  if ! orchestrator_dependencies_ready "$id"; then
    state_set "$id" "$STATE_BLOCKED" 'dependency not satisfied'
    return "$EXIT_DEPENDENCY_FAILED"
  fi

  ACTIVE_SCOPE="${ORCH_SCOPE[$id]}"
  state_set "$id" "$STATE_RUNNING" 'precheck'
  log_info ENGINE "module=$id phase=PRECHECK scope=$ACTIVE_SCOPE"
  if orchestrator_call "${ORCH_PRECHECK[$id]}"; then :; else rc=$?; state_set "$id" "$STATE_FAILED" 'precheck failed'; ACTIVE_SCOPE="$previous_scope"; return "$rc"; fi

  state_set "$id" "$STATE_RUNNING" 'plan'
  log_info ENGINE "module=$id phase=PLAN scope=$ACTIVE_SCOPE"
  if orchestrator_call "${ORCH_PLAN[$id]}"; then :; else rc=$?; state_set "$id" "$STATE_FAILED" 'plan failed'; ACTIVE_SCOPE="$previous_scope"; return "$rc"; fi

  state_set "$id" "$STATE_RUNNING" 'apply'
  log_info ENGINE "module=$id phase=APPLY scope=$ACTIVE_SCOPE dry_run=${DRY_RUN:-true}"
  if orchestrator_call "${ORCH_APPLY[$id]}"; then :; else rc=$?; state_set "$id" "$STATE_FAILED" 'apply failed'; ACTIVE_SCOPE="$previous_scope"; return "$rc"; fi

  state_set "$id" "$STATE_RUNNING" 'postcheck'
  log_info ENGINE "module=$id phase=POSTCHECK scope=$ACTIVE_SCOPE"
  if orchestrator_call "${ORCH_POSTCHECK[$id]}"; then :; else rc=$?; state_set "$id" "$STATE_FAILED" 'postcheck failed'; ACTIVE_SCOPE="$previous_scope"; return "$rc"; fi

  state_set "$id" "$STATE_SUCCESS" 'all phases completed'
  ACTIVE_SCOPE="$previous_scope"
}

orchestrator_report() {
  local report="$REPORT_ROOT/$RUN_ID-orchestrator.txt" id current
  : > "$report"
  for id in "${ORCH_ORDER[@]}"; do
    current="$(state_get "$id" 2>/dev/null || printf 'PENDING')"
    printf '%s\t%s\t%s\n' "$id" "${ORCH_SCOPE[$id]}" "$current" >> "$report"
  done
  printf '%s\n' "$report"
}

orchestrator_run_all() {
  local id rc=0
  for id in "${ORCH_ORDER[@]}"; do
    if orchestrator_run_module "$id"; then
      :
    else
      rc=$?
      log_error ENGINE "orchestration stopped module=$id rc=$rc"
      orchestrator_report >/dev/null
      return "$rc"
    fi
  done
  orchestrator_report >/dev/null
}
