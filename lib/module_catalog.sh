#!/usr/bin/env bash

declare -Ag CATALOG_SCOPE=()
declare -Ag CATALOG_DEPS=()
declare -Ag CATALOG_PATH=()
declare -ag CATALOG_ORDER=()

module_catalog_reset() {
  CATALOG_SCOPE=()
  CATALOG_DEPS=()
  CATALOG_PATH=()
  CATALOG_ORDER=()
}

module_catalog_load() {
  local file="$1" line id scope deps path extra
  [[ -r "$file" ]] || return "$EXIT_INVALID_ARGUMENT"
  module_catalog_reset

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    IFS='|' read -r id scope deps path extra <<< "$line"
    [[ -z "${extra:-}" ]] || return "$EXIT_INVALID_ARGUMENT"
    [[ "$id" =~ ^[A-Za-z0-9_.-]+$ ]] || return "$EXIT_INVALID_ARGUMENT"
    scope_valid "$scope" || return "$EXIT_INVALID_ARGUMENT"
    [[ "$path" =~ ^modules/[A-Za-z0-9_./-]+\.sh$ ]] || return "$EXIT_INVALID_ARGUMENT"
    [[ -z "${CATALOG_SCOPE[$id]+x}" ]] || return "$EXIT_INVALID_ARGUMENT"

    CATALOG_SCOPE["$id"]="$scope"
    CATALOG_DEPS["$id"]="$deps"
    CATALOG_PATH["$id"]="$path"
    CATALOG_ORDER+=("$id")
  done < "$file"
}

module_catalog_validate() {
  local id dep path
  for id in "${CATALOG_ORDER[@]}"; do
    path="${CATALOG_PATH[$id]}"
    [[ -f "$REPO_ROOT/$path" ]] || return "$EXIT_INVALID_ARGUMENT"
    for dep in ${CATALOG_DEPS[$id]:-}; do
      [[ -n "${CATALOG_SCOPE[$dep]+x}" ]] || return "$EXIT_DEPENDENCY_FAILED"
    done
  done
}

module_catalog_print_plan() {
  local index=0 id
  for id in "${CATALOG_ORDER[@]}"; do
    index=$((index + 1))
    printf '%02d | %-17s | %-9s | deps=%-35s | %s\n' \
      "$index" "$id" "${CATALOG_SCOPE[$id]}" "${CATALOG_DEPS[$id]:--}" "${CATALOG_PATH[$id]}"
  done
}
