#!/usr/bin/env bash

config_load_file() {
  local file="$1"
  local line key value

  [[ -r "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      printf 'Invalid config line in %s: %s\n' "$file" "$line" >&2
      return "$EXIT_INVALID_ARGUMENT"
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"
}

config_load_dir() {
  local dir="$1"
  local file
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' file; do
    config_load_file "$file" || return $?
  done < <(find "$dir" -maxdepth 1 -type f -name '*.conf' -print0 | sort -z)
}
