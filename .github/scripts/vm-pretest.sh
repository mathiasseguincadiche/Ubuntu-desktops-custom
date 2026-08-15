#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
LAB="$ROOT/.vm-pretest"
IMAGE_BASE_URL="https://cloud-images.ubuntu.com/releases/26.04/release"
IMAGE_NAME="ubuntu-26.04-server-cloudimg-amd64.img"
SSH_PORT="2222"
VM_USER="ubuntu"
REPORT="$LAB/report.txt"
CONSOLE="$LAB/console.log"
PIDFILE="$LAB/qemu.pid"
SSH_KEY="$LAB/id_ed25519"
SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

mkdir -p "$LAB"
: >"$REPORT"

report() { printf '%s\n' "$*" | tee -a "$REPORT"; }
cleanup() {
  if [[ -s "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

report '=== Ubuntu-desktops-custom REAL VM PRE-TEST ==='
report "commit=${GITHUB_SHA:-local}"
report "host=$(uname -a)"

report '[1/10] Install host-side VM test dependencies'
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  qemu-system-x86 qemu-utils cloud-image-utils openssh-client curl ca-certificates \
  gnupg ubuntu-cloudimage-keyring libvirt-clients dnsutils >/dev/null

report '[2/10] Download and authenticate Ubuntu 26.04 cloud image'
cd "$LAB"
curl -fL --retry 4 --retry-delay 3 -o "$IMAGE_NAME" "$IMAGE_BASE_URL/$IMAGE_NAME"
curl -fL --retry 4 --retry-delay 3 -o SHA256SUMS "$IMAGE_BASE_URL/SHA256SUMS"
curl -fL --retry 4 --retry-delay 3 -o SHA256SUMS.gpg "$IMAGE_BASE_URL/SHA256SUMS.gpg"
gpgv --keyring /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg SHA256SUMS.gpg SHA256SUMS
expected="$(awk -v n="$IMAGE_NAME" '$2==n || $2=="*"n {print $1; exit}' SHA256SUMS)"
[[ -n "$expected" ]] || { report 'FAIL: image checksum not found'; exit 20; }
printf '%s  %s\n' "$expected" "$IMAGE_NAME" | sha256sum -c -
report 'PASS: Canonical signature + SHA256 image verification'

report '[3/10] Prepare minimal cloud-init and VM disk'
ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY"
PUBKEY="$(cat "$SSH_KEY.pub")"
cat >user-data <<EOF
#cloud-config
users:
  - default
  - name: $VM_USER
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUBKEY
ssh_pwauth: false
disable_root: true
EOF
cat >meta-data <<'EOF'
instance-id: ubuntu-desktops-custom-ci
local-hostname: ubuntu-devops-ci
EOF
cloud-localds seed.img user-data meta-data
cp "$IMAGE_NAME" disk.qcow2
qemu-img resize disk.qcow2 40G >/dev/null
qemu-img check disk.qcow2

report '[4/10] Select KVM acceleration or TCG fallback'
ACCEL='tcg'
QEMU_CPU='max'
if [[ -e /dev/kvm ]]; then
  sudo chmod 666 /dev/kvm || true
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL='kvm'
    QEMU_CPU='host'
  fi
fi
report "selected_acceleration=$ACCEL"

start_vm() {
  local accel="$1" cpu="$2"
  rm -f "$PIDFILE"
  qemu-system-x86_64 \
    -name ubuntu-devops-ci \
    -machine "accel=$accel" \
    -cpu "$cpu" \
    -smp 2 \
    -m 4096 \
    -drive file=disk.qcow2,format=qcow2,if=virtio \
    -drive file=seed.img,format=raw,if=virtio,readonly=on \
    -device virtio-net-pci,netdev=net0 \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
    -display none \
    -serial "file:$CONSOLE" \
    -daemonize \
    -pidfile "$PIDFILE"
}

if ! start_vm "$ACCEL" "$QEMU_CPU"; then
  if [[ "$ACCEL" == 'kvm' ]]; then
    report 'WARN: KVM launch failed; retrying with QEMU TCG'
    ACCEL='tcg'
    QEMU_CPU='max'
    start_vm "$ACCEL" "$QEMU_CPU"
  else
    report 'FAIL: QEMU TCG launch failed'
    exit 21
  fi
fi
report "active_acceleration=$ACCEL"

report '[5/10] Wait for SSH and minimal cloud-init completion'
ssh_ready=0
for _ in $(seq 1 120); do
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" true >/dev/null 2>&1; then
    ssh_ready=1
    break
  fi
  sleep 5
done
if (( ssh_ready == 0 )); then
  report 'FAIL: SSH did not become ready'
  tail -n 200 "$CONSOLE" | tee -a "$REPORT" || true
  exit 22
fi
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo cloud-init status --wait --long'

report 'Install guest bootstrap packages with explicit retry outside cloud-init'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'set -Eeuo pipefail
  for attempt in 1 2 3 4 5; do
    if sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl bind9-dnsutils git qemu-guest-agent; then
      sudo systemctl enable --now qemu-guest-agent || true
      exit 0
    fi
    echo "guest apt bootstrap attempt $attempt failed" >&2
    sleep $((attempt * 5))
  done
  exit 1
'
report 'PASS: SSH + cloud-init + guest package bootstrap'

report '[6/10] Validate Ubuntu guest, Internet and DNS contract'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" \
  "grep -q '^VERSION_ID=\"26.04\"' /etc/os-release"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'curl -fsSI --max-time 20 https://github.com >/dev/null'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'getent hosts github.com >/dev/null'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'dig +time=4 +tries=1 @9.9.9.9 github.com A +short | grep -q .'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'dig +time=4 +tries=1 @1.1.1.1 github.com A +short | grep -q .'
report 'PASS: Ubuntu 26.04 + Internet + system DNS + Quad9 + Cloudflare'

report '[7/10] Copy repository VM installers into guest'
scp "${SSH_OPTS[@]}" -r "$ROOT/scripts/devops-vm" "$VM_USER@127.0.0.1:/tmp/ubuntu-desktops-custom-devops-vm"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'chmod +x /tmp/ubuntu-desktops-custom-devops-vm/*.sh'

report '[8/10] Execute real DevOps installers inside Ubuntu 26.04 VM'
for installer in install_iac.sh install_docker.sh install_kubernetes.sh install_cloud_clis.sh install_devsecops.sh; do
  report "RUN: $installer"
  ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo /tmp/ubuntu-desktops-custom-devops-vm/$installer"
done

report '[9/10] Runtime smoke tests'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'set -Eeuo pipefail
  git --version
  terraform version
  ansible --version
  docker --version
  docker buildx version
  docker compose version
  kubectl version --client=true
  helm version --short
  kind version
  aws --version
  az version >/dev/null
  trivy --version
  gitleaks version
  shellcheck --version
  hadolint --version
  checkov --version
  sudo docker run --rm hello-world >/dev/null
'
report 'PASS: DevOps runtime smoke tests'

report '[10/10] Reboot persistence test'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo reboot' || true
sleep 10
reboot_ready=0
for _ in $(seq 1 90); do
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'cloud-init status >/dev/null && docker --version >/dev/null && terraform version >/dev/null' >/dev/null 2>&1; then
    reboot_ready=1
    break
  fi
  sleep 5
done
(( reboot_ready == 1 )) || { report 'FAIL: guest did not recover after reboot'; exit 23; }
report 'PASS: VM reboot persistence'

report 'VERDICT: REAL UBUNTU 26.04 VM PRE-TEST PASS'
