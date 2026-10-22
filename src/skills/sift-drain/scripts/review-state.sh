#!/usr/bin/env bash
# Snapshot integration Git state and every tracker file, then compare two
# snapshots while allowing only exact, validated, newly published events.
#
# Usage:
#   review-state.sh snapshot > STATE
#   review-state.sh compare BEFORE AFTER [--allow-event EVENT.md]...
#
# EVENT.md may be absolute under this project or relative to its root. An
# allowance applies only when that exact path is new in AFTER. It never permits
# a changed or deleted historical file.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
DRAIN_LOG="$SCRIPT_DIR/drain-log.sh"

usage() {
  echo 'usage: review-state.sh snapshot' >&2
  echo '       review-state.sh compare BEFORE AFTER [--allow-event EVENT.md]...' >&2
  exit 2
}

snapshot_state() (
  set -euo pipefail
  cd "$ROOT"
  printf '%s\n' '@review-state-v1' '@git-head'
  git rev-parse HEAD
  printf '%s\n' '@git-status'
  git status --porcelain
  printf '%s\n' '@git-diff'
  git diff HEAD | cksum
  printf '%s\n' '@git-refs'
  git for-each-ref
  printf '%s\n' '@git-stashes'
  git stash list
  printf '%s\n' '@git-untracked'
  git ls-files --others --exclude-standard | while IFS= read -r f; do
    cksum "$f"
  done
  printf '%s\n' '@tracker'
  find .ai/sift -type f -exec cksum {} + | LC_ALL=C sort
)

snapshot_parts() {
  local input="$1" prefix="$2" tracker="$3" markers="$4" expected="$5"
  [ -r "$input" ] || { echo "error: review state: snapshot is not readable: $input" >&2; return 2; }
  grep '^@' "$input" > "$markers" || :
  printf '%s\n' '@review-state-v1' '@git-head' '@git-status' '@git-diff' '@git-refs' \
    '@git-stashes' '@git-untracked' '@tracker' > "$expected"
  cmp -s "$expected" "$markers" || {
    echo "error: review state: malformed snapshot markers: $input" >&2
    return 2
  }
  sed '/^@tracker$/,$d' "$input" > "$prefix"
  sed -n '/^@tracker$/,$p' "$input" | sed '1d' > "$tracker"
  awk '
    function path(s) {
      sub(/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", s)
      return s
    }
    $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ { exit 2 }
    {
      p = path($0)
      if (p !~ /^\.ai\/sift\// || seen[p]++) exit 2
    }
  ' "$tracker" || {
    echo "error: review state: malformed tracker rows: $input" >&2
    return 2
  }
}

tracker_changes() {
  awk '
    function path(s) {
      sub(/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", s)
      return s
    }
    NR == FNR { p = path($0); before[p] = $0; next }
    { p = path($0); after[p] = $0 }
    END {
      for (p in before) {
        if (!(p in after)) print "deleted\t" p
        else if (before[p] != after[p]) print "changed\t" p
      }
      for (p in after) if (!(p in before)) print "added\t" p
    }
  ' "$1" "$2" | LC_ALL=C sort
}

normalize_event_path() {
  case "$1" in
    "$ROOT"/.ai/sift/*) printf '%s\n' "${1#"$ROOT"/}" ;;
    .ai/sift/*) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
}

line_for_path() {
  awk -v want="$2" '
    function path(s) {
      sub(/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", s)
      return s
    }
    path($0) == want { print; exit }
  ' "$1"
}

compare_state() {
  [ "$#" -ge 2 ] || usage
  local before="$1" after="$2"; shift 2
  local tmp before_git after_git before_tracker after_tracker changes additions
  local markers expected auth type path candidate fields stored_run stored_event
  local tail run_id event_tail event_id live_row snapshot_row
  local bad=0 tab
  tab="$(printf '\t')"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sift-review-state.XXXXXXXXXX")" || exit 2
  before_git="$tmp/before.git"; after_git="$tmp/after.git"
  before_tracker="$tmp/before.tracker"; after_tracker="$tmp/after.tracker"
  changes="$tmp/changes"; additions="$tmp/additions"; auth="$tmp/auth"
  markers="$tmp/markers"; expected="$tmp/expected"
  : > "$auth"
  trap 'rm -rf "$tmp"' EXIT

  while [ "$#" -gt 0 ]; do
    [ "$1" = '--allow-event' ] && [ "$#" -ge 2 ] || usage
    candidate="$(normalize_event_path "$2")" || {
      echo "review state violation: authorization is outside .ai/sift: $2" >&2
      bad=1
      shift 2
      continue
    }
    if grep -Fqx -- "$candidate" "$auth"; then
      echo "review state violation: duplicate event authorization: $candidate" >&2
      bad=1
    else
      printf '%s\n' "$candidate" >> "$auth"
    fi
    shift 2
  done

  snapshot_parts "$before" "$before_git" "$before_tracker" "$markers" "$expected" || exit 2
  snapshot_parts "$after" "$after_git" "$after_tracker" "$markers" "$expected" || exit 2
  if ! cmp -s "$before_git" "$after_git"; then
    echo 'review state violation: integration Git state changed' >&2
    bad=1
  fi

  tracker_changes "$before_tracker" "$after_tracker" > "$changes" || exit 2
  : > "$additions"
  while IFS="$tab" read -r type path; do
    [ -n "$type" ] || continue
    case "$type" in
      changed)
        echo "review state violation: changed historical tracker file: $path" >&2
        bad=1
        ;;
      deleted)
        echo "review state violation: deleted historical tracker file: $path" >&2
        bad=1
        ;;
      added) printf '%s\n' "$path" >> "$additions" ;;
      *) echo 'error: review state: invalid comparison result' >&2; exit 2 ;;
    esac
  done < "$changes"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if ! grep -Fqx -- "$path" "$auth"; then
      echo "review state violation: unauthorized tracker addition: $path" >&2
      bad=1
    fi
  done < "$additions"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if ! grep -Fqx -- "$path" "$additions"; then
      echo "review state violation: authorization does not name a new tracker file: $path" >&2
      bad=1
      continue
    fi
    tail=${path#.ai/sift/runs/}
    run_id=${tail%%/*}
    event_tail=${tail#*/events/}
    event_id=${event_tail%%/*}
    if [ "$path" != ".ai/sift/runs/$run_id/events/$event_id/event.md" ] || \
       [ -z "$run_id" ] || [ -z "$event_id" ]; then
      echo "review state violation: authorized path is not a final event record: $path" >&2
      bad=1
      continue
    fi
    if [ ! -f "$ROOT/$path" ] || [ -L "$ROOT/$path" ] ||
       ! env SIFT_ROOT="$ROOT" "$DRAIN_LOG" event-validate "$ROOT/$path" >/dev/null 2>&1; then
      echo "review state violation: authorized event is invalid: $path" >&2
      bad=1
      continue
    fi
    fields="$(env SIFT_ROOT="$ROOT" "$DRAIN_LOG" event-fields "$ROOT/$path")" || {
      echo "review state violation: authorized event fields are unreadable: $path" >&2
      bad=1
      continue
    }
    stored_run="$(printf '%s\n' "$fields" | awk -F '\t' '$1 == "run_id" { print $2 }')"
    stored_event="$(printf '%s\n' "$fields" | awk -F '\t' '$1 == "event_id" { print $2 }')"
    if [ "$stored_run" != "$run_id" ] || [ "$stored_event" != "$event_id" ]; then
      echo "review state violation: authorized event identities do not match its path: $path" >&2
      bad=1
      continue
    fi
    live_row="$(cd "$ROOT" && cksum "$path")" || exit 2
    snapshot_row="$(line_for_path "$after_tracker" "$path")"
    if [ "$live_row" != "$snapshot_row" ]; then
      echo "review state violation: authorized event changed after the snapshot: $path" >&2
      bad=1
    fi
  done < "$auth"

  rm -rf "$tmp"
  trap - EXIT
  [ "$bad" -eq 0 ]
}

case "${1:-}" in
  snapshot)
    [ "$#" -eq 1 ] || usage
    snapshot_state
    ;;
  compare)
    shift
    compare_state "$@"
    ;;
  *) usage ;;
esac
