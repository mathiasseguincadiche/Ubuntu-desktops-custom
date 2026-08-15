#!/usr/bin/env bash
set -Eeuo pipefail

vm_identity_file() {
  printf '%s/%s-vm-identity.env\n' "${STATE_ROOT:?}" "${VM_DEVOPS_NAME:-ubuntu-devops}"
}

vm_identity_derive() {
  local name="${VM_DEVOPS_NAME:-ubuntu-devops}"
  local digest byte ip_octet mac
  digest="$(printf '%s' "$name" | sha256sum | awk '{print $1}')"
  byte=$((16#${digest:0:2}))
  ip_octet=$((100 + (byte % 101)))
  mac="52:54:00:${digest:2:2}:${digest:4:2}:${digest:6:2}"
  printf '%s|192.168.50.%d\n' "$mac" "$ip_octet"
}

vm_identity_ssh_precheck() {
  assert_scope VM_DEVOPS
  [[ "${VM_DEVOPS_ADDRESS_MODE:-}" == 'dhcp-reservation' ]] || return "$EXIT_PRECHECK_FAILED"
  command -v sha256sum >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  [[ -n "${VM_ADMIN_USER:-}" ]] || return "$EXIT_MANUAL_ACTION_REQUIRED"
  [[ "$VM_ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || return "$EXIT_INVALID_ARGUMENT"
  [[ -n "${VM_ADMIN_SSH_PUBLIC_KEY_FILE:-}" && -r "$VM_ADMIN_SSH_PUBLIC_KEY_FILE" ]] || return "$EXIT_MANUAL_ACTION_REQUIRED"
  grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))[[:space:]]+' "$VM_ADMIN_SSH_PUBLIC_KEY_FILE" || return "$EXIT_INVALID_ARGUMENT"
}

vm_identity_ssh_plan() {
  cat <<'EOF'
VM IDENTITY / SSH PLAN:
- derive a deterministic locally-administered libvirt MAC from VM name
- derive a deterministic candidate DHCP reservation inside 192.168.50.100-200
- reject the candidate if libvirt already assigns the IP to another MAC
- keep the guest as DHCP client; libvirt/dnsmasq remains the addressing authority
- require runtime admin username and public SSH key file; never commit private keys
- expose SSH through devops-nat only; physical-LAN isolation is enforced by the KVM network guard
EOF
}

vm_identity_ssh_apply() {
  local derived mac ip identity network="${VM_DEVOPS_NETWORK:-devops-nat}"
  derived="$(vm_identity_derive)"
  mac="${derived%%|*}"
  ip="${derived##*|}"
  identity="$(vm_identity_file)"

  if ! is_true "${DRY_RUN:-true}" && command -v virsh >/dev/null 2>&1; then
    local xml leases
    xml="$(sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dumpxml "$network" 2>/dev/null || true)"
    if grep -Eq "<host[^>]+ip=['\"]${ip//./\.}['\"]" <<< "$xml" && \
       ! grep -Eq "<host[^>]+mac=['\"]${mac//:/\\:}['\"][^>]+ip=['\"]${ip//./\.}['\"]|<host[^>]+ip=['\"]${ip//./\.}['\"][^>]+mac=['\"]${mac//:/\\:}['\"]" <<< "$xml"; then
      log_error VM_DEVOPS "DHCP reservation candidate $ip is already assigned to another MAC"
      return "$EXIT_MANUAL_ACTION_REQUIRED"
    fi
    leases="$(sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-dhcp-leases "$network" 2>/dev/null || true)"
    if grep -Fq "$ip/" <<< "$leases" && ! grep -Fiq "$mac" <<< "$leases"; then
      log_error VM_DEVOPS "DHCP candidate $ip is currently leased to another MAC"
      return "$EXIT_MANUAL_ACTION_REQUIRED"
    fi
  fi

  safe_mkdir "$(dirname "$identity")"
  {
    printf 'VM_DEVOPS_RESOLVED_MAC=%s\n' "$mac"
    printf 'VM_DEVOPS_RESOLVED_IP=%s\n' "$ip"
    printf 'VM_ADMIN_USER=%s\n' "$VM_ADMIN_USER"
  } > "$identity"
  chmod 0600 "$identity"
  log_info VM_DEVOPS "resolved identity mac=$mac ip=$ip"
}

vm_identity_ssh_postcheck() {
  local identity
  identity="$(vm_identity_file)"
  [[ -s "$identity" ]] || return "$EXIT_POSTCHECK_FAILED"
  grep -Eq '^VM_DEVOPS_RESOLVED_MAC=52:54:00:' "$identity" || return "$EXIT_POSTCHECK_FAILED"
  grep -Eq '^VM_DEVOPS_RESOLVED_IP=192\.168\.50\.(1[0-9][0-9]|200)$' "$identity" || return "$EXIT_POSTCHECK_FAILED"
}
