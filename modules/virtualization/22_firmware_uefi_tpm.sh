#!/usr/bin/env bash
set -Eeuo pipefail

kvm_firmware_precheck() {
  assert_scope KVM
  command -v apt-get >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v sudo >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

kvm_firmware_plan() {
  cat <<'EOF'
KVM FIRMWARE / TPM PLAN:
- install OVMF UEFI firmware for x86_64 guests
- install swtpm and swtpm-tools for per-VM TPM 2.0 emulation
- keep Secure Boot/TPM policy per VM rather than globally forcing it
- preserve NVRAM/TPM state in the backup contract when a guest uses them
- every package mutation is executed only through run_mutating
EOF
}

kvm_firmware_apply() {
  run_mutating KVM sudo env DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ovmf swtpm swtpm-tools || return "$EXIT_APPLY_FAILED"
}

kvm_firmware_postcheck() {
  if is_true "${DRY_RUN:-true}"; then
    log_info KVM 'dry-run: OVMF/TPM postcheck deferred'
    return 0
  fi
  command -v swtpm >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  find /usr/share -maxdepth 4 -type f \( -name 'OVMF_CODE*.fd' -o -name 'OVMF_VARS*.fd' \) -print -quit | grep -q . || return "$EXIT_POSTCHECK_FAILED"
}
