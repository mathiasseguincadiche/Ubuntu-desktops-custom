#!/usr/bin/env bash

# Capture the privileged HOST configuration into a user-readable archive before
# invoking Restic. Restic itself remains unprivileged so the external repository
# never becomes root-owned. The tar archive preserves numeric ownership, ACLs
# and xattrs for later staged restoration.

BACKUP_PRIVILEGED_ARCHIVE=''

backup_privileged_system_paths() {
  cat <<'EOF'
etc/fstab
etc/apt/sources.list
etc/apt/sources.list.d
etc/apt/keyrings
etc/apt/preferences.d
etc/systemd/system
etc/default
etc/modprobe.d
etc/sysctl.d
etc/udev/rules.d
EOF
}

backup_capture_privileged_system_state() {
  local inventory_dir="${1:?}" archive tmp manifest uid gid relative
  local -a requested=() existing=()

  command -v sudo >/dev/null 2>&1 || backup_fail 'sudo is required to capture privileged system configuration'
  command -v tar >/dev/null 2>&1 || backup_fail 'tar is required to capture privileged system configuration'

  mapfile -t requested < <(backup_privileged_system_paths)
  for relative in "${requested[@]}"; do
    [[ -e "/$relative" ]] || continue
    existing+=("$relative")
  done
  (( ${#existing[@]} > 0 )) || backup_fail 'no privileged system configuration path is available for backup'

  archive="$inventory_dir/system-config.tar"
  tmp="${archive}.tmp.${BASHPID:-$$}"
  manifest="$inventory_dir/system-config.paths.txt"
  uid="$(id -u)"
  gid="$(id -g)"

  ui_info 'Capture privilégiée de la configuration système (ACL/xattrs/propriétaires conservés)...'

  # Validate sudo interactively before starting the archive so any password
  # prompt is explicit in the operator terminal rather than appearing midway
  # through the Restic command.
  sudo -v || backup_fail 'sudo authentication failed while preparing privileged system backup' "$EXIT_SECURITY_BLOCK"

  if ! sudo tar --acls --xattrs --numeric-owner -C / -cpf "$tmp" -- "${existing[@]}" >> "$RESTIC_UI_LOG" 2>&1; then
    sudo rm -f -- "$tmp" >/dev/null 2>&1 || true
    backup_fail 'privileged system configuration capture failed'
  fi

  sudo chown "$uid:$gid" -- "$tmp" >> "$RESTIC_UI_LOG" 2>&1 \
    || backup_fail 'cannot return privileged backup archive ownership to the current user'
  chmod 0600 "$tmp" || backup_fail 'cannot protect privileged backup archive permissions'
  mv -f -- "$tmp" "$archive" || backup_fail 'cannot finalize privileged backup archive'

  tar -tf "$archive" > "$manifest" \
    || backup_fail 'privileged system backup archive cannot be reopened after creation' "$EXIT_POSTCHECK_FAILED"
  chmod 0600 "$manifest"

  # Fail closed if a path that existed when the capture started is absent from
  # the resulting archive.
  for relative in "${existing[@]}"; do
    if [[ -d "/$relative" ]]; then
      grep -Fqx "$relative/" "$manifest" || grep -Fq "$relative/" "$manifest" \
        || backup_fail "privileged backup archive is missing expected directory: /$relative" "$EXIT_POSTCHECK_FAILED"
    else
      grep -Fqx "$relative" "$manifest" \
        || backup_fail "privileged backup archive is missing expected file: /$relative" "$EXIT_POSTCHECK_FAILED"
    fi
  done

  BACKUP_PRIVILEGED_ARCHIVE="$archive"
}
