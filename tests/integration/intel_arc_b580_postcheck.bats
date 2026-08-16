#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "Arc B580 PCI postcheck matches 8086:e20b bound to xe" {
  local root="$BATS_TEST_TMPDIR/pci"
  local dev="$root/0000:03:00.0"
  mkdir -p "$dev" "$BATS_TEST_TMPDIR/drivers/xe"
  printf '%s\n' '0x030000' > "$dev/class"
  printf '%s\n' '0x8086' > "$dev/vendor"
  printf '%s\n' '0xe20b' > "$dev/device"
  ln -s "$BATS_TEST_TMPDIR/drivers/xe" "$dev/driver"

  run bash -c "
    set -Eeuo pipefail
    EXPECTED_GPU_PCI_VENDOR=8086
    EXPECTED_GPU_PCI_DEVICE=e20b
    EXPECTED_GPU_KERNEL_DRIVER=xe
    GPU_SYSFS_ROOT='$root'
    source '$REPO_ROOT/modules/host/03_graphics_intel_arc.sh'
    host_graphics_expected_pci_device_path
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *'0000:03:00.0'* ]]
}

@test "Arc B580 PCI postcheck rejects the expected device when xe is not bound" {
  local root="$BATS_TEST_TMPDIR/pci-wrong-driver"
  local dev="$root/0000:03:00.0"
  mkdir -p "$dev" "$BATS_TEST_TMPDIR/drivers/i915"
  printf '%s\n' '0x030000' > "$dev/class"
  printf '%s\n' '0x8086' > "$dev/vendor"
  printf '%s\n' '0xe20b' > "$dev/device"
  ln -s "$BATS_TEST_TMPDIR/drivers/i915" "$dev/driver"

  run bash -c "
    set -Eeuo pipefail
    EXPECTED_GPU_PCI_VENDOR=8086
    EXPECTED_GPU_PCI_DEVICE=e20b
    EXPECTED_GPU_KERNEL_DRIVER=xe
    GPU_SYSFS_ROOT='$root'
    source '$REPO_ROOT/modules/host/03_graphics_intel_arc.sh'
    host_graphics_expected_pci_device_path
  "

  [ "$status" -ne 0 ]
}

@test "Arc B580 Vulkan postcheck matches the physical discrete Intel Mesa device" {
  local fixture="$BATS_TEST_TMPDIR/vulkan-summary.txt"
  cat > "$fixture" <<'EOF'
GPU0:
    apiVersion         = 1.4.335
    driverVersion      = 26.0.3
    vendorID           = 0x8086
    deviceID           = 0xe20b
    deviceType         = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
    deviceName         = Intel(R) Arc(tm) B580 Graphics (BMG G21)
    driverID           = DRIVER_ID_INTEL_OPEN_SOURCE_MESA
    driverName         = Intel open-source Mesa driver
GPU1:
    vendorID           = 0x10005
    deviceID           = 0x0000
    deviceType         = PHYSICAL_DEVICE_TYPE_CPU
    driverID           = DRIVER_ID_MESA_LLVMPIPE
EOF

  run bash -c "
    set -Eeuo pipefail
    EXPECTED_GPU_PCI_VENDOR=8086
    EXPECTED_GPU_PCI_DEVICE=e20b
    source '$REPO_ROOT/modules/host/03_graphics_intel_arc.sh'
    host_graphics_vulkan_summary_matches_expected \"\$(cat '$fixture')\"
  "

  [ "$status" -eq 0 ]
}

@test "graphics postcheck no longer uses lspci grep pipelines under pipefail" {
  run grep -n -E 'lspci[^|]*\|[^|]*grep' "$REPO_ROOT/modules/host/03_graphics_intel_arc.sh"
  [ "$status" -ne 0 ]
}

@test "hardware contract pins the physical Arc B580 identity" {
  grep -Fx 'EXPECTED_GPU_PCI_VENDOR=8086' "$REPO_ROOT/config/hardware.conf"
  grep -Fx 'EXPECTED_GPU_PCI_DEVICE=e20b' "$REPO_ROOT/config/hardware.conf"
  grep -Fx 'EXPECTED_GPU_KERNEL_DRIVER=xe' "$REPO_ROOT/config/hardware.conf"
}
