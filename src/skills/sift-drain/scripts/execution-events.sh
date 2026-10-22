#!/usr/bin/env bash
# Internal immutable diagnostic writer, sourced by drain-log.sh.

EVENT_SCHEMA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/execution-event.awk"

event_error() { printf 'error: execution event: %s\n' "$*" >&2; return 2; }

event_format() {
  LC_ALL=C SIFT_EVENT_PREFIX="$PREFIX" awk -v mode=input -v emit=record -f "$EVENT_SCHEMA"
}

event_validate() {
  [ -f "$1" ] || { event_error "not a record file: $1"; return 2; }
  LC_ALL=C SIFT_EVENT_PREFIX="$PREFIX" awk -v mode=record -v emit="${2:-}" -f "$EVENT_SCHEMA" < "$1"
}

event_write() {
  [ $# -ge 1 ] || { usage; return 2; }
  local kind="$1" run_id='' arg key dir event_id
  local have_run=0 have_timestamp=0 have_version=0
  case "$kind" in
    *$'\n'*) event_error 'multiline kind'; return 2 ;;
  esac
  shift
  for arg in "$@"; do
    case "$arg" in
      *$'\n'*) event_error 'multiline operand'; return 2 ;;
    esac
    key=${arg%%=*}
    case "$key" in
      run_id) have_run=1; run_id=${arg#*=} ;;
      timestamp) have_timestamp=1 ;;
      version) have_version=1 ;;
      event_id|kind) event_error "generated field: $key"; return 2 ;;
    esac
  done
  if [ "$have_run" -eq 0 ] && [ "$kind" != run-start ]; then
    event_error 'run_id is required'; return 2
  fi
  # Validate every operand before creating even a directory. No eval and no
  # shared mutable ID counter. The placeholder cannot escape this process.
  local fields=("event_id=event.pending" "kind=$kind" "$@")
  local run_index=${#fields[@]}
  [ "$have_run" -eq 1 ] || fields+=("run_id=run.pending")
  [ "$have_version" -eq 1 ] || fields+=("version=1")
  if [ "$have_timestamp" -eq 0 ]; then
    local timestamp
    timestamp=$(date +%s) || { event_error 'cannot read clock'; return 2; }
    fields+=("timestamp=$timestamp")
  fi
  printf '%s\n' "${fields[@]}" | event_format > /dev/null || return 2
  if [ "$have_run" -eq 0 ]; then
    mkdir -p "$SIFT/runs" || { event_error 'cannot create runs directory'; return 2; }
    dir=$(mktemp -d "$SIFT/runs/run.XXXXXXXXXX") || { event_error 'cannot reserve run'; return 2; }
    run_id=${dir##*/}
    fields[$run_index]="run_id=$run_id"
  fi
  mkdir -p "$SIFT/runs/$run_id/events" || { event_error 'cannot create events directory'; return 2; }
  dir=$(mktemp -d "$SIFT/runs/$run_id/events/event.XXXXXXXXXX") || {
    event_error 'cannot reserve event directory'; return 2;
  }
  event_id=${dir##*/}
  fields[0]="event_id=$event_id"
  # Only this producer knows/owns dir. A crash leaves the directory observable;
  # event.md alone is the publication marker. Never clean incomplete evidence.
  if ! printf '%s\n' "${fields[@]}" | event_format > "$dir/event.pending"; then
    event_error "cannot stage record in $dir"; return 2
  fi
  mv "$dir/event.pending" "$dir/event.md" || { event_error "cannot publish $dir"; return 2; }
  printf '%s\n' "$dir/event.md"
}
