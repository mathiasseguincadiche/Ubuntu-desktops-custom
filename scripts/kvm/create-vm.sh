#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config/vm-profiles.conf
source "$REPO_ROOT/config/vm-profiles.conf"

usage() {
  cat <<'EOF'
Usage: create-vm.sh PROFILE [--plan]

Profiles:
  ubuntu-desktop  Ubuntu Desktop 26.04 LTS, accelerated virtio-gpu/virgl/SPICE
  windows-11      Windows 11, UEFI Secure Boot capable + TPM 2.0 + VirtIO

The command is intentionally plan-only until profile-specific ISO validation,
firmware discovery and host render-node prechecks have succeeded.
EOF
}

profile="${1:-}"
[[ "${2:---plan}" == '--plan' ]] || { usage >&2; exit 2; }

case "$profile" in
  ubuntu-desktop)
    cat <<EOF
PROFILE: ubuntu-desktop
name=$UBUNTU_DESKTOP_VM_NAME
vcpu=$UBUNTU_DESKTOP_VM_VCPU
ram_mb=$UBUNTU_DESKTOP_VM_RAM_MB
disk_gb=$UBUNTU_DESKTOP_VM_DISK_GB
network=$VM_PROFILE_NETWORK
machine=$UBUNTU_DESKTOP_VM_MACHINE
cpu=$UBUNTU_DESKTOP_VM_CPU_MODE
firmware=$UBUNTU_DESKTOP_VM_FIRMWARE
display=$UBUNTU_DESKTOP_VM_DISPLAY
video=$UBUNTU_DESKTOP_VM_VIDEO
3d_acceleration=$UBUNTU_DESKTOP_VM_3D_ACCEL
render_node=$UBUNTU_DESKTOP_VM_RENDER_NODE
EOF
    ;;
  windows-11)
    cat <<EOF
PROFILE: windows-11
name=$WINDOWS11_VM_NAME
vcpu=$WINDOWS11_VM_VCPU
ram_mb=$WINDOWS11_VM_RAM_MB
disk_gb=$WINDOWS11_VM_DISK_GB
network=$VM_PROFILE_NETWORK
machine=$WINDOWS11_VM_MACHINE
cpu=$WINDOWS11_VM_CPU_MODE
firmware=$WINDOWS11_VM_FIRMWARE
tpm=$WINDOWS11_VM_TPM
display=$WINDOWS11_VM_DISPLAY
video=$WINDOWS11_VM_VIDEO
virtio_driver_iso_required=$WINDOWS11_VM_VIRTIO_DRIVER_ISO_REQUIRED
EOF
    ;;
  -h|--help|'') usage ;;
  *) printf 'Unknown VM profile: %s\n' "$profile" >&2; usage >&2; exit 2 ;;
esac
