#!/usr/bin/env bash

module_adapter_function_prefix() {
  local id="$1"
  printf '%s' "${id//./_}"
}

module_adapter_register() {
  local id="$1" path prefix precheck_fn plan_fn apply_fn postcheck_fn
  [[ -n "${CATALOG_SCOPE[$id]+x}" ]] || return "$EXIT_INVALID_ARGUMENT"
  path="${CATALOG_PATH[$id]}"
  [[ "$path" =~ ^modules/[A-Za-z0-9_./-]+\.sh$ ]] || return "$EXIT_INVALID_ARGUMENT"
  [[ -f "$REPO_ROOT/$path" ]] || return "$EXIT_INVALID_ARGUMENT"

  # shellcheck disable=SC1090
  source "$REPO_ROOT/$path"

  prefix="$(module_adapter_function_prefix "$id")"
  precheck_fn="${prefix}_precheck"
  plan_fn="${prefix}_plan"
  apply_fn="${prefix}_apply"
  postcheck_fn="${prefix}_postcheck"

  declare -F "$precheck_fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"
  declare -F "$plan_fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"
  declare -F "$apply_fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"
  declare -F "$postcheck_fn" >/dev/null || return "$EXIT_INVALID_ARGUMENT"

  orchestrator_register \
    "$id" "${CATALOG_SCOPE[$id]}" "${CATALOG_DEPS[$id]}" \
    "$precheck_fn" "$plan_fn" "$apply_fn" "$postcheck_fn"
}
