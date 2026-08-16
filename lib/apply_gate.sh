#!/usr/bin/env bash

apply_gate_current_commit() {
  git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'UNKNOWN\n'
}

apply_gate_tracked_worktree_changes() {
  command -v git >/dev/null 2>&1 || return "$EXIT_SECURITY_BLOCK"
  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return "$EXIT_SECURITY_BLOCK"
  git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=no
}

apply_gate_require_clean_worktree() {
  local changes
  is_true "${REAL_APPLY_REQUIRE_CLEAN_WORKTREE:-true}" || return 0

  changes="$(apply_gate_tracked_worktree_changes)" || {
    log_error ENGINE 'REAL APPLY requires a readable Git worktree.'
    return "$EXIT_SECURITY_BLOCK"
  }
  [[ -z "$changes" ]] || {
    log_error ENGINE "REAL APPLY requires a clean tracked Git worktree. Changes: $(printf '%s' "$changes" | tr '\n' ';')"
    return "$EXIT_SECURITY_BLOCK"
  }
}

apply_gate_write_dryrun_proof() {
  local proof="$REPO_ROOT/${REAL_APPLY_DRYRUN_PROOF_FILE:-state/real-apply/full-dry-run.pass}"
  local commit
  apply_gate_require_clean_worktree || return "$EXIT_SECURITY_BLOCK"
  commit="$(apply_gate_current_commit)"
  safe_mkdir "$(dirname "$proof")"
  {
    printf 'commit=%s\n' "$commit"
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'created_epoch=%s\n' "$(date +%s)"
    printf 'worktree=clean_tracked\n'
    printf 'verdict=FULL_DRY_RUN_PASS\n'
  } > "$proof"
}

apply_gate_verify_dryrun_proof() {
  local proof="$REPO_ROOT/${REAL_APPLY_DRYRUN_PROOF_FILE:-state/real-apply/full-dry-run.pass}"
  local current recorded
  apply_gate_require_clean_worktree || return "$EXIT_SECURITY_BLOCK"
  [[ -s "$proof" ]] || return "$EXIT_SECURITY_BLOCK"
  current="$(apply_gate_current_commit)"
  recorded="$(awk -F= '$1=="commit" {print $2; exit}' "$proof")"
  [[ -n "$recorded" && "$recorded" == "$current" && "$current" != 'UNKNOWN' ]] || return "$EXIT_SECURITY_BLOCK"
  grep -Fqx 'worktree=clean_tracked' "$proof" || return "$EXIT_SECURITY_BLOCK"
  grep -Fqx 'verdict=FULL_DRY_RUN_PASS' "$proof" || return "$EXIT_SECURITY_BLOCK"
}

apply_gate_verify_backup_proof() {
  local proof="$REPO_ROOT/${REAL_APPLY_BACKUP_PROOF_FILE:-state/real-apply/backup-verified.pass}"
  local current recorded created now max_age age
  apply_gate_require_clean_worktree || return "$EXIT_SECURITY_BLOCK"
  [[ -s "$proof" ]] || return "$EXIT_SECURITY_BLOCK"
  grep -Fqx 'verdict=BACKUP_VERIFIED' "$proof" || return "$EXIT_SECURITY_BLOCK"
  grep -Fqx 'worktree=clean_tracked' "$proof" || return "$EXIT_SECURITY_BLOCK"

  current="$(apply_gate_current_commit)"
  recorded="$(awk -F= '$1=="commit" {print $2; exit}' "$proof")"
  [[ -n "$recorded" && "$recorded" == "$current" && "$current" != 'UNKNOWN' ]] || return "$EXIT_SECURITY_BLOCK"

  created="$(awk -F= '$1=="created_epoch" {print $2; exit}' "$proof")"
  [[ "$created" =~ ^[0-9]+$ ]] || return "$EXIT_SECURITY_BLOCK"
  now="$(date +%s)"
  max_age="${REAL_APPLY_BACKUP_MAX_AGE_SECONDS:-86400}"
  [[ "$max_age" =~ ^[0-9]+$ ]] || return "$EXIT_INVALID_ARGUMENT"
  age=$((now - created))
  (( age >= 0 && age <= max_age )) || return "$EXIT_SECURITY_BLOCK"
}

apply_gate_require_tty() {
  is_true "${REAL_APPLY_REQUIRE_TTY:-true}" || return 0
  [[ -t 0 && -t 1 ]] || return "$EXIT_SECURITY_BLOCK"
}

apply_gate_require_exact_confirmation() {
  local expected="${REAL_APPLY_CONFIRMATION_PHRASE:-JE_CONFIRME_L_EXECUTION_REELLE_UBUNTU_DESKTOPS_CUSTOM}"
  local answer
  is_true "${REAL_APPLY_REQUIRE_EXACT_CONFIRMATION:-true}" || return 0
  printf 'Pour autoriser l execution REELLE, saisir exactement : %s\n' "$expected"
  read -r -p '> ' answer
  [[ "$answer" == "$expected" ]] || return "$EXIT_SECURITY_BLOCK"
}

apply_gate_check() {
  is_true "${REAL_APPLY_FEATURE_ENABLED:-false}" || {
    log_error ENGINE 'REAL APPLY feature flag is closed.'
    return "$EXIT_SECURITY_BLOCK"
  }
  apply_gate_require_tty || return "$EXIT_SECURITY_BLOCK"
  apply_gate_require_clean_worktree || return "$EXIT_SECURITY_BLOCK"
  if is_true "${REAL_APPLY_REQUIRE_CURRENT_COMMIT_DRY_RUN:-true}"; then
    apply_gate_verify_dryrun_proof || {
      log_error ENGINE 'REAL APPLY requires a successful full dry-run proof for the current clean commit.'
      return "$EXIT_SECURITY_BLOCK"
    }
  fi
  if is_true "${REAL_APPLY_REQUIRE_VERIFIED_BACKUP:-true}"; then
    apply_gate_verify_backup_proof || {
      log_error ENGINE 'REAL APPLY requires a recent verified backup proof for the current clean commit.'
      return "$EXIT_SECURITY_BLOCK"
    }
  fi
  apply_gate_require_exact_confirmation || {
    log_error ENGINE 'REAL APPLY confirmation phrase rejected.'
    return "$EXIT_SECURITY_BLOCK"
  }
}

apply_gate_open_runtime() {
  apply_gate_check || return "$?"
  export DRY_RUN=false
  export REAL_MACHINE_APPROVED=true
  log_warn ENGINE 'REAL MACHINE APPLY runtime gate OPEN for this process only.'
}

apply_gate_confirm_phase() {
  local phase="$1" answer
  is_true "${REAL_APPLY_PHASE_CONFIRMATION:-true}" || return 0
  printf 'Phase suivante: %s. Continuer? saisir OUI_%s : ' "$phase" "$phase"
  read -r answer
  [[ "$answer" == "OUI_$phase" ]] || return "$EXIT_MANUAL_ACTION_REQUIRED"
}
