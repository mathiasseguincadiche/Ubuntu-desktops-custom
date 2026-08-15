#!/usr/bin/env bash
# Skeleton contract only. Real command execution is intentionally not implemented yet.
run_command() { printf '[BLOCKED][SKELETON] %s\n' "$*"; return 10; }
run_remote() { printf '[BLOCKED][SKELETON][REMOTE] %s\n' "$*"; return 10; }
