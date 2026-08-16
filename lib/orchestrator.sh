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
  UI_SCOPE_CURRENT=''
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

orchestrator_call_phase() {
  local id="$1" phase="$2" fn="$3"
  [[ -z "$fn" ]] && return 0
  declare -F "$fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"

  log_module_boundary "$id" "$phase" BEGIN
  if ui_is_operator; then
    if "$fn" >> "$MODULE_LOG" 2>&1; then
      log_module_boundary "$id" "$phase" END_OK
      return 0
    else
      local rc=$?
      log_module_boundary "$id" "$phase" "END_FAIL rc=$rc"
      return "$rc"
    fi
  fi

  if "$fn"; then
    log_module_boundary "$id" "$phase" END_OK
    return 0
  else
    local rc=$?
    log_module_boundary "$id" "$phase" "END_FAIL rc=$rc"
    return "$rc"
  fi
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

orchestrator_module_position() {
  local wanted="$1" id index=0
  for id in "${ORCH_ORDER[@]}"; do
    index=$((index + 1))
    if [[ "$id" == "$wanted" ]]; then
      printf '%s\n' "$index"
      return 0
    fi
  done
  return "$EXIT_INVALID_ARGUMENT"
}

orchestrator_prepare_ui_step() {
  local id="$1" scope="$2" index
  ui_is_operator || return 0
  if [[ "${UI_SCOPE_CURRENT:-}" != "$scope" ]]; then
    ui_section "$scope"
  fi
  index="$(orchestrator_module_position "$id")"
  ui_step_begin "$index" "${#ORCH_ORDER[@]}" "$id"
}

orchestrator_fail_ui_step() {
  local phase="$1" rc="$2"
  ui_is_operator || return 0
  ui_step_fail "Phase $phase en échec (rc=$rc). Détail : $MODULE_LOG"
}

orchestrator_run_module() {
  local id="$1" previous_scope="${ACTIVE_SCOPE:-}" rc=0 module_scope
  [[ -n "${ORCH_SCOPE[$id]+x}" ]] || return "$EXIT_INVALID_ARGUMENT"
  module_scope="${ORCH_SCOPE[$id]}"
  ACTIVE_SCOPE="$module_scope"
  orchestrator_prepare_ui_step "$id" "$module_scope"

  if orchestrator_should_resume_skip "$id"; then
    log_info ENGINE "resume skip module=$id state=$(state_get "$id")"
    ui_is_operator && ui_step_skip
    ACTIVE_SCOPE="$previous_scope"
    return 0
  fi

  if ! orchestrator_dependencies_ready "$id"; then
    state_set "$id" "$STATE_BLOCKED" 'dependency not satisfied'
    ui_is_operator && ui_step_fail 'Dépendance non satisfaite. Aucune mutation lancée.'
    ACTIVE_SCOPE="$previous_scope"
    return "$EXIT_DEPENDENCY_FAILED"
  fi

  state_set "$id" "$STATE_RUNNING" 'precheck'
  log_info ENGINE "module=$id phase=PRECHECK scope=$ACTIVE_SCOPE"
  if orchestrator_call_phase "$id" PRECHECK "${ORCH_PRECHECK[$id]}"; then :; else
    rc=$?
    state_set "$id" "$STATE_FAILED" 'precheck failed'
    orchestrator_fail_ui_step PRECHECK "$rc"
    ACTIVE_SCOPE="$previous_scope"
    return "$rc"
  fi

  state_set "$id" "$STATE_RUNNING" 'plan'
  log_info ENGINE "module=$id phase=PLAN scope=$ACTIVE_SCOPE"
  if orchestrator_call_phase "$id" PLAN "${ORCH_PLAN[$id]}"; then :; else
    rc=$?
    state_set "$id" "$STATE_FAILED" 'plan failed'
    orchestrator_fail_ui_step PLAN "$rc"
    ACTIVE_SCOPE="$previous_scope"
    return "$rc"
  fi

  state_set "$id" "$STATE_RUNNING" 'apply'
  log_info ENGINE "module=$id phase=APPLY scope=$ACTIVE_SCOPE dry_run=${DRY_RUN:-true}"
  if orchestrator_call_phase "$id" APPLY "${ORCH_APPLY[$id]}"; then :; else
    rc=$?
    state_set "$id" "$STATE_FAILED" 'apply failed'
    orchestrator_fail_ui_step APPLY "$rc"
    ACTIVE_SCOPE="$previous_scope"
    return "$rc"
  fi

  state_set "$id" "$STATE_RUNNING" 'postcheck'
  log_info ENGINE "module=$id phase=POSTCHECK scope=$ACTIVE_SCOPE"
  if orchestrator_call_phase "$id" POSTCHECK "${ORCH_POSTCHECK[$id]}"; then :; else
    rc=$?
    state_set "$id" "$STATE_FAILED" 'postcheck failed'
    orchestrator_fail_ui_step POSTCHECK "$rc"
    ACTIVE_SCOPE="$previous_scope"
    return "$rc"
  fi

  state_set "$id" "$STATE_SUCCESS" 'all phases completed'
  ui_is_operator && ui_step_ok
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

orchestrator_run_scope() {
  local wanted_scope="$1" id rc=0 matched=0
  scope_valid "$wanted_scope" || return "$EXIT_INVALID_ARGUMENT"
  UI_SCOPE_CURRENT=''
  for id in "${ORCH_ORDER[@]}"; do
    [[ "${ORCH_SCOPE[$id]}" == "$wanted_scope" ]] || continue
    matched=1
    if orchestrator_run_module "$id"; then
      :
    else
      rc=$?
      log_error ENGINE "scope orchestration stopped scope=$wanted_scope module=$id rc=$rc"
      orchestrator_report >/dev/null
      return "$rc"
    fi
  done
  (( matched == 1 )) || return "$EXIT_INVALID_ARGUMENT"
  orchestrator_report >/dev/null
}

orchestrator_run_all() {
  local id rc=0
  UI_SCOPE_CURRENT=''
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
