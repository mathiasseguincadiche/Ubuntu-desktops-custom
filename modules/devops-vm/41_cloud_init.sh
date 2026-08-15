#!/usr/bin/env bash
set -Eeuo pipefail

vm_cloud_init_paths() {
  local name="${VM_DEVOPS_NAME:-ubuntu-devops}"
  printf '%s|%s|%s|%s\n' \
    "${KVM_POOL_PATH:-/data/libvirt/images}/base/${VM_DEVOPS_IMAGE:-ubuntu-26.04-server-cloudimg-amd64.img}" \
    "${KVM_POOL_PATH:-/data/libvirt/images}/seeds/${name}-seed.img" \
    "${STATE_ROOT:?}/${name}-user-data.yaml" \
    "${STATE_ROOT:?}/${name}-meta-data.yaml"
}

vm_cloud_init_precheck() {
  assert_scope VM_DEVOPS
  [[ -f "$REPO_ROOT/virtualization/cloud-init/user-data.tpl" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -f "$REPO_ROOT/virtualization/cloud-init/network-config.tpl" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -f "$REPO_ROOT/scripts/kvm/fetch_ubuntu_2604_cloud_image.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -s "${STATE_ROOT:?}/${VM_DEVOPS_NAME:-ubuntu-devops}-vm-identity.env" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -n "${VM_ADMIN_SSH_PUBLIC_KEY_FILE:-}" && -r "$VM_ADMIN_SSH_PUBLIC_KEY_FILE" ]] || return "$EXIT_MANUAL_ACTION_REQUIRED"
}

vm_cloud_init_plan() {
  cat <<'EOF'
VM CLOUD IMAGE / CLOUD-INIT PLAN:
- install cloud-image-utils plus Ubuntu keyring/GnuPG verification dependencies
- download the current released Ubuntu Server 26.04 amd64 cloud image from cloud-images.ubuntu.com
- verify SHA256SUMS.gpg with /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg before trusting the SHA-256 digest
- verify the downloaded image against the signed SHA-256 manifest
- render NoCloud user-data from the versioned template using runtime admin username/public SSH key
- generate a NoCloud seed with cloud-localds
- keep password SSH disabled and root login disabled
- guest remains DHCP client; stable addressing is owned by libvirt DHCP reservation
- every HOST-side mutation is executed only through run_mutating
EOF
}

vm_cloud_init_apply() {
  local packed base seed user_data meta_data identity admin_user ssh_key
  packed="$(vm_cloud_init_paths)"
  IFS='|' read -r base seed user_data meta_data <<< "$packed"
  identity="${STATE_ROOT}/${VM_DEVOPS_NAME:-ubuntu-devops}-vm-identity.env"
  admin_user="$(awk -F= '$1=="VM_ADMIN_USER"{print $2}' "$identity")"
  ssh_key="$(head -n1 "$VM_ADMIN_SSH_PUBLIC_KEY_FILE")"
  [[ -n "$admin_user" && -n "$ssh_key" ]] || return "$EXIT_APPLY_FAILED"

  run_mutating VM_DEVOPS sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    cloud-image-utils ubuntu-keyring curl gnupg || return "$EXIT_APPLY_FAILED"
  run_mutating VM_DEVOPS sudo install -d -m 0755 "$(dirname "$base")" "$(dirname "$seed")" || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}" || [[ ! -s "$base" ]]; then
    run_mutating VM_DEVOPS sudo bash "$REPO_ROOT/scripts/kvm/fetch_ubuntu_2604_cloud_image.sh" "$base" || return "$EXIT_APPLY_FAILED"
  fi

  python3 - "$REPO_ROOT/virtualization/cloud-init/user-data.tpl" "$user_data" "$admin_user" "$ssh_key" <<'PY'
from pathlib import Path
import sys
template, output, user, key = sys.argv[1:]
text = Path(template).read_text()
text = text.replace('__VM_ADMIN_USER__', user).replace('__VM_ADMIN_SSH_PUBLIC_KEY__', key)
if '__VM_ADMIN_' in text:
    raise SystemExit('unresolved cloud-init placeholder')
Path(output).write_text(text)
PY
  chmod 0600 "$user_data"
  {
    printf 'instance-id: %s-v1\n' "${VM_DEVOPS_NAME:-ubuntu-devops}"
    printf 'local-hostname: %s\n' "${VM_DEVOPS_NAME:-ubuntu-devops}"
  } > "$meta_data"
  chmod 0600 "$meta_data"

  run_mutating VM_DEVOPS sudo cloud-localds "$seed" "$user_data" "$meta_data" || return "$EXIT_APPLY_FAILED"
}

vm_cloud_init_postcheck() {
  grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  grep -F 'ssh_pwauth: false' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then
    log_info VM_DEVOPS 'dry-run: cloud image/seed runtime postcheck deferred'
    return 0
  fi
  local packed base seed user_data meta_data
  packed="$(vm_cloud_init_paths)"
  IFS='|' read -r base seed user_data meta_data <<< "$packed"
  [[ -s "$base" && -s "$seed" && -s "$user_data" && -s "$meta_data" ]] || return "$EXIT_POSTCHECK_FAILED"
}
