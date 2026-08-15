#!/usr/bin/env bash
set -Eeuo pipefail

backup_host_precheck() { assert_scope BACKUP; }
backup_host_plan() {
  cat <<'EOF'
HOST RECOVERY BACKUP:
- back up reproducibility-critical configuration, not a blind raw copy of the running OS
- capture package/application inventory and enabled services as recovery metadata
- capture project configuration and generated reports required to rebuild
- preserve selected user configuration only through explicit allowlists
- exclude secrets unless separately encrypted and explicitly opted in
- recovery model: clean Ubuntu 26.04 install -> restore configuration/data -> converge through project modules -> validate
EOF
}
backup_host_apply() { log_info BACKUP 'HOST backup APPLY disabled during architecture/pre-test phase'; }
backup_host_postcheck() { return 0; }
