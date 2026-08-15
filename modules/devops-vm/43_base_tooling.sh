#!/usr/bin/env bash
set -Eeuo pipefail

vm_base_precheck() {
  assert_scope VM_DEVOPS
}

vm_base_plan() {
  cat <<'EOF'
PLAN ONLY:
- base CLI: curl, wget, ca-certificates, gnupg, jq, yq, unzip, zip, tar, rsync, tree, htop, tmux
- build/runtime helpers: make, gcc, python3, python3-venv, pipx
- networking/debug: dnsutils, iproute2, net-tools, traceroute, tcpdump, openssh-client
- install from Ubuntu repositories unless an upstream vendor repository is required and verified
- keep packages minimal enough for a server VM; no desktop stack
EOF
}

vm_base_apply() { log_info VM_DEVOPS 'base tooling APPLY intentionally disabled during architecture/pre-test phase'; }
vm_base_postcheck() { return 0; }
