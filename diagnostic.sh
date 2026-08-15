#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"

engine_bootstrap
pretest_run
