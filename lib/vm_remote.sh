#!/usr/bin/env bash

vm_remote_identity_file() {
  printf '%s/%s-vm-identity.env\n' "${STATE_ROOT:?}" "${VM_DEVOPS_NAME:-ubuntu-devops}"
}

vm_remote_prepare() {
  local file
  file="$(vm_remote_identity_file)"
  VM_REMOTE_KNOWN_HOSTS="${STATE_ROOT}/vm-known-hosts"

  if is_true "${DRY_RUN:-true}"; then
    if [[ -s "$file" ]]; then
      VM_REMOTE_USER="$(awk -F= '$1=="VM_ADMIN_USER"{print $2}' "$file")"
      VM_REMOTE_IP="$(awk -F= '$1=="VM_DEVOPS_RESOLVED_IP"{print $2}' "$file")"
    fi
    VM_REMOTE_USER="${VM_REMOTE_USER:-devops}"
    VM_REMOTE_IP="${VM_REMOTE_IP:-192.168.50.150}"
    VM_ADMIN_SSH_PRIVATE_KEY_FILE="${VM_ADMIN_SSH_PRIVATE_KEY_FILE:-/dev/null}"
    safe_mkdir "$(dirname "$VM_REMOTE_KNOWN_HOSTS")"
    return 0
  fi

  [[ -s "$file" ]] || return "$EXIT_PRECHECK_FAILED"
  VM_REMOTE_USER="$(awk -F= '$1=="VM_ADMIN_USER"{print $2}' "$file")"
  VM_REMOTE_IP="$(awk -F= '$1=="VM_DEVOPS_RESOLVED_IP"{print $2}' "$file")"

  [[ -n "$VM_REMOTE_USER" && -n "$VM_REMOTE_IP" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -n "${VM_ADMIN_SSH_PRIVATE_KEY_FILE:-}" && -r "$VM_ADMIN_SSH_PRIVATE_KEY_FILE" ]] || return "$EXIT_MANUAL_ACTION_REQUIRED"
  safe_mkdir "$(dirname "$VM_REMOTE_KNOWN_HOSTS")"
}

vm_remote_shell_payload() {
  local command="${1:?remote command required}"
  printf 'bash -lc %q\n' "$command"
}

vm_remote_run_mutating() {
  local remote_command="${1:?remote command required}" payload
  vm_remote_prepare || return $?
  payload="$(vm_remote_shell_payload "$remote_command")"
  run_mutating VM_DEVOPS ssh \
    -i "$VM_ADMIN_SSH_PRIVATE_KEY_FILE" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$VM_REMOTE_KNOWN_HOSTS" \
    "$VM_REMOTE_USER@$VM_REMOTE_IP" \
    "$payload"
}

vm_remote_run_readonly() {
  local remote_command="${1:?remote command required}" payload
  vm_remote_prepare || return $?
  payload="$(vm_remote_shell_payload "$remote_command")"
  run_readonly VM_DEVOPS ssh \
    -i "$VM_ADMIN_SSH_PRIVATE_KEY_FILE" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$VM_REMOTE_KNOWN_HOSTS" \
    "$VM_REMOTE_USER@$VM_REMOTE_IP" \
    "$payload"
}

vm_remote_copy_mutating() {
  local local_path="${1:?local path required}"
  local remote_path="${2:?remote path required}"
  vm_remote_prepare || return $?
  [[ -r "$local_path" ]] || return "$EXIT_PRECHECK_FAILED"
  run_mutating VM_DEVOPS scp \
    -i "$VM_ADMIN_SSH_PRIVATE_KEY_FILE" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$VM_REMOTE_KNOWN_HOSTS" \
    "$local_path" "$VM_REMOTE_USER@$VM_REMOTE_IP:$remote_path"
}
