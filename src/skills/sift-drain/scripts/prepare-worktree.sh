#!/usr/bin/env bash
# Prepare one isolated worker branch without checking out the integration branch.
# Tracker paths stay in the original tree; pass SIFT_ROOT explicitly to workers.
#
# Project setup hook: if <root>/.ai/sift/config/worktree-setup exists, where
# <root> is `git rev-parse --show-toplevel` of the calling directory, it must be
# an executable regular file. It runs once in the new worktree, with stdin from
# /dev/null and its stdout sent to stderr, and with these variables set:
#   SIFT_ROOT         the original root
#   SIFT_WORKTREE     the new worktree path, as given
#   SIFT_BRANCH       the new branch
#   SIFT_BASE_COMMIT  the resolved base SHA
#
# Exit codes:
#   0  worktree ready; stdout ends with the worktree=, branch= and base= lines
#   1  bad arguments, existing path, or a hook that is not an executable file
#      (checked before any worktree or branch exists)
#   3  the hook failed; the worktree and branch are kept for inspection and
#      stderr names both and the hook's status
#   other non-zero statuses come from git unchanged
#
# Optional preparation telemetry is enabled only when both
# SIFT_PREPARE_RUN_ID and SIFT_PREPARE_ATTEMPT_ID are set. SIFT_ROOT keeps its
# existing meaning as the project whose immutable event tree receives records.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRAIN_LOG="$SCRIPT_DIR/drain-log.sh"
PREPARE_EVENT_RUN_ID="${SIFT_PREPARE_RUN_ID:-}"
PREPARE_EVENT_ATTEMPT_ID="${SIFT_PREPARE_ATTEMPT_ID:-}"
PREPARE_EVENT_SPAN_ID=''
PREPARE_EVENT_STARTED_AT=''
PREPARE_FAILURE_REASON='command-failure'
PREPARE_FAILURE_DETAIL=''

finish_with_preparation_clock_gap() {
  local command_status="$1" detail="$2"
  printf 'prepare-worktree: preparation instrumentation gap: %s; span %s remains incomplete\n' \
    "$detail" "$PREPARE_EVENT_SPAN_ID" >&2
  if [ "$command_status" -eq 0 ]; then
    exit 2
  fi
  exit "$command_status"
}

finish_preparation_event() {
  local command_status=$? ended_at duration event_status
  local fields
  trap - EXIT

  if ! ended_at="$(date +%s 2>/dev/null)"; then
    finish_with_preparation_clock_gap "$command_status" 'end clock unavailable'
  fi
  case "$ended_at" in
    ''|*[!0-9]*)
      finish_with_preparation_clock_gap "$command_status" 'end clock unavailable'
      ;;
  esac
  if [ "$ended_at" -lt "$PREPARE_EVENT_STARTED_AT" ]; then
    finish_with_preparation_clock_gap "$command_status" \
      "end clock moved backwards (start=$PREPARE_EVENT_STARTED_AT end=$ended_at)"
  fi
  duration=$((ended_at - PREPARE_EVENT_STARTED_AT))

  fields=(event span-end "run_id=$PREPARE_EVENT_RUN_ID"
    "attempt_id=$PREPARE_EVENT_ATTEMPT_ID" "span_id=$PREPARE_EVENT_SPAN_ID"
    actor=helper activity=preparation "timestamp=$ended_at" "duration=$duration"
    "exit_status=$command_status")
  if [ "$command_status" -ne 0 ]; then
    fields+=(outcome=failed "reason=$PREPARE_FAILURE_REASON")
    [ -z "$PREPARE_FAILURE_DETAIL" ] || fields+=("reason_detail=$PREPARE_FAILURE_DETAIL")
  else
    fields+=(outcome=done)
  fi

  if "$DRAIN_LOG" "${fields[@]}" >/dev/null; then event_status=0
  else event_status=$?
  fi
  if [ "$command_status" -eq 0 ] && [ "$event_status" -ne 0 ]; then
    exit "$event_status"
  fi
  exit "$command_status"
}

case "$PREPARE_EVENT_RUN_ID:$PREPARE_EVENT_ATTEMPT_ID" in
  :) ;;
  *:|:*)
    echo 'prepare-worktree telemetry requires both SIFT_PREPARE_RUN_ID and SIFT_PREPARE_ATTEMPT_ID' >&2
    exit 2
    ;;
  *)
    PREPARE_EVENT_STARTED_AT="$(date +%s)"
    record="$("$DRAIN_LOG" event span-start "run_id=$PREPARE_EVENT_RUN_ID" \
      "attempt_id=$PREPARE_EVENT_ATTEMPT_ID" actor=helper activity=preparation \
      "timestamp=$PREPARE_EVENT_STARTED_AT")"
    span_dir=${record%/*}
    PREPARE_EVENT_SPAN_ID=${span_dir##*/}
    trap finish_preparation_event EXIT
    ;;
esac

if [ "$#" -ne 3 ]; then
  echo 'usage: prepare-worktree.sh <base-branch> <new-branch> <absolute-new-path>' >&2
  exit 1
fi
BASE=$1
BRANCH=$2
WORKTREE=$3
case "$WORKTREE" in
  /*) ;;
  *) echo 'worktree path must be absolute' >&2; exit 1 ;;
esac
[ ! -e "$WORKTREE" ] && [ ! -L "$WORKTREE" ] || {
  echo "worktree path already exists: $WORKTREE" >&2; exit 1;
}
git check-ref-format --branch "$BASE" >/dev/null
git check-ref-format --branch "$BRANCH" >/dev/null
COMMIT=$(git rev-parse --verify "$BASE^{commit}")
ROOT=$(git rev-parse --show-toplevel)
HOOK="$ROOT/.ai/sift/config/worktree-setup"
if [ -e "$HOOK" ] || [ -L "$HOOK" ]; then
  [ -f "$HOOK" ] && [ -x "$HOOK" ] || {
    echo "worktree setup hook is not an executable file: $HOOK" >&2; exit 1;
  }
else
  HOOK=''
fi
git worktree add -b "$BRANCH" "$WORKTREE" "$COMMIT"
if [ -n "$HOOK" ]; then
  if (cd "$WORKTREE" && SIFT_ROOT="$ROOT" SIFT_WORKTREE="$WORKTREE" \
       SIFT_BRANCH="$BRANCH" SIFT_BASE_COMMIT="$COMMIT" "$HOOK" < /dev/null) >&2; then
    :
  else
    status=$?
    PREPARE_FAILURE_REASON='setup-failure'
    PREPARE_FAILURE_DETAIL="hook-exit-$status"
    printf 'worktree setup failed (hook exit %s); worktree kept for inspection\nworktree: %s\nbranch: %s\n' \
      "$status" "$WORKTREE" "$BRANCH" >&2
    exit 3
  fi
fi
printf 'worktree=%s\nbranch=%s\nbase=%s\n' "$WORKTREE" "$BRANCH" "$COMMIT"
