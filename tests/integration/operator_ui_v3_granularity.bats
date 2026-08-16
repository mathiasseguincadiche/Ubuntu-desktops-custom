#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/ui.sh"
  source "$REPO_ROOT/lib/operator_details.sh"
  source "$REPO_ROOT/lib/live_progress.sh"
}

@test "every orchestration module has a human success detail" {
  local line id scope deps path detail count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    IFS='|' read -r id scope deps path <<< "$line"
    detail="$(ui_module_detail "$id")"
    [ -n "$detail" ]
    count=$((count + 1))
  done < "$REPO_ROOT/manifests/module-plan.conf"
  [ "$count" -eq 41 ]
}

@test "HOST long-running actions expose useful component names" {
  UI_STEP_ID='host.graphics'
  run ui_live_action_label HOST 'sudo apt-get -y install mesa-vulkan-drivers mesa-utils vulkan-tools intel-media-va-driver vainfo intel-gpu-tools'
  [ "$status" -eq 0 ]
  [[ "$output" == *'Mesa/Vulkan'* ]]
  [[ "$output" == *'VA-API'* ]]

  UI_STEP_ID='host.multimedia'
  run ui_live_action_label HOST 'sudo apt-get -y install ffmpeg gstreamer1.0-plugins-base pipewire wireplumber'
  [[ "$output" == *'FFmpeg'* ]]
  [[ "$output" == *'GStreamer'* ]]
  [[ "$output" == *'PipeWire'* ]]

  UI_STEP_ID='host.observability'
  run ui_live_action_label HOST 'sudo apt-get -y install nvme-cli smartmontools lm-sensors v4l-utils'
  [[ "$output" == *'NVMe/SMART'* ]]
  [[ "$output" == *'webcam'* ]]
}

@test "KVM and VM_DEVOPS actions expose concrete tool bundles" {
  UI_STEP_ID='kvm.stack'
  run ui_live_action_label KVM 'sudo apt-get -y install qemu-system-x86 libvirt-daemon-system virt-install virt-manager'
  [[ "$output" == *'QEMU/libvirt'* ]]
  [[ "$output" == *'virt-install/manager/viewer'* ]]

  UI_STEP_ID='vm.docker'
  run ui_live_action_label VM_DEVOPS 'ssh ubuntu-devops install docker'
  [[ "$output" == *'Docker Engine'* ]]
  [[ "$output" == *'Buildx'* ]]
  [[ "$output" == *'Compose'* ]]

  UI_STEP_ID='vm.devsecops'
  run ui_live_action_label VM_DEVOPS 'ssh ubuntu-devops install devsecops'
  [[ "$output" == *'Trivy'* ]]
  [[ "$output" == *'Gitleaks'* ]]
  [[ "$output" == *'ShellCheck'* ]]
}

@test "finished live action format includes elapsed seconds" {
  run ui_live_action_format 'Docker Engine + Buildx + Compose' OK 12
  [ "$status" -eq 0 ]
  [[ "$output" == *'OK · 12s'* ]]
}

@test "bootstrap loads operator details before live progress and runner" {
  bootstrap="$REPO_ROOT/lib/bootstrap.sh"
  grep -F 'source "$REPO_ROOT/lib/operator_details.sh"' "$bootstrap"
  grep -F 'source "$REPO_ROOT/lib/live_progress.sh"' "$bootstrap"
  grep -F 'source "$REPO_ROOT/lib/runner.sh"' "$bootstrap"

  details_line="$(grep -n '^[[:space:]]*source .*operator_details\.sh' "$bootstrap" | head -1 | cut -d: -f1)"
  live_line="$(grep -n '^[[:space:]]*source .*live_progress\.sh' "$bootstrap" | head -1 | cut -d: -f1)"
  runner_line="$(grep -n '^[[:space:]]*source .*runner\.sh' "$bootstrap" | head -1 | cut -d: -f1)"
  [ -n "$details_line" ]
  [ -n "$live_line" ]
  [ -n "$runner_line" ]
  [ "$details_line" -lt "$live_line" ]
  [ "$live_line" -lt "$runner_line" ]
}
