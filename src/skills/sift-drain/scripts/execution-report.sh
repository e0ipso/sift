#!/usr/bin/env bash
# Internal read-only observation, sourced by drain-log.sh. Scratch is external.
report_events() (
  [ "$#" -ge 1 ] && [ "$#" -le 3 ] || usage
  local run=$1 worktree=${2:-$ROOT} as_of=${3:-} scratch dir fields stored_run stored_event
  local here
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  case "$run" in ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*|[._-]*)
    echo 'error: report run must be an identity' >&2; exit 2 ;;
  esac
  [ "${#run}" -le 128 ] && [ -d "$SIFT/runs/$run/events" ] || {
    echo 'error: no event directory for requested run' >&2; exit 2;
  }
  if [ "$#" -lt 3 ]; then as_of=$(date +%s) || exit 2; fi
  printf '%s\n' "$as_of" | LC_ALL=C awk 'NR!=1 || $0 !~ /^(0|[1-9][0-9]*)$/ || length($0)>15 {bad=1} END {exit bad}' || {
    echo 'error: report observation clock must be a canonical epoch' >&2; exit 2;
  }
  worktree=$(cd "$worktree" && pwd -P) || exit 2
  local scratch_base
  scratch_base=$(cd "${TMPDIR:-/tmp}" && pwd -P) || exit 2
  case "$scratch_base/" in "$ROOT/"*|"$worktree/"*) scratch_base=/tmp ;; esac
  scratch=$(mktemp -d "$scratch_base/sift-report.XXXXXXXXXX") || exit 2
  trap 'rm -rf "$scratch"' EXIT
  : > "$scratch/events"
  # The glob observes producer directories once. Only final regular files enter
  # the graph; pending files are never parsed, even if locally well formed.
  for dir in "$SIFT/runs/$run/events"/*; do
    [ -d "$dir" ] || continue
    if [ -L "$dir" ] || [ -L "$dir/event.md" ]; then
      printf 'D\tinvalid-publication\t%s\n' "${dir##*/}" >> "$scratch/events"
    elif [ ! -f "$dir/event.md" ]; then
      printf 'D\tincomplete-publication\t%s\n' "${dir##*/}" >> "$scratch/events"
    elif fields=$(event_validate "$dir/event.md" fields 2> "$scratch/error"); then
      stored_run=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="run_id" {print $2}')
      stored_event=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="event_id" {print $2}')
      if [ "$stored_run" != "$run" ] || [ "$stored_event" != "${dir##*/}" ]; then
        printf 'D\tidentity-path-mismatch\t%s\n' "${dir##*/}" >> "$scratch/events"
      else
        printf 'E\t%s\n%s\n' "$stored_event" "$fields" >> "$scratch/events"
      fi
    else
      printf 'D\tmalformed-record\t%s\n' "${dir##*/}" >> "$scratch/events"
    fi
  done
  SIFT_REPORT_NOW="$as_of" SIFT_REPORT_RUN="$run" LC_ALL=C \
    awk -f "$here/execution-report.awk" "$scratch/events" > "$scratch/graph" || exit 2
  report_obligations "$here" "$scratch" || exit 2
  report_tickets > "$scratch/tickets" || exit 2
  # Deduplicate actual validator calls across members, attempts and waves. The
  # current declaration supplies the scope, never an opaque event assertion.
  # Use the same obligation selection as final rendering. Historical worker
  # checks and superseded gate results must not create extra validation work.
  SIFT_REPORT_REQUESTS=1 LC_ALL=C awk -f "$here/execution-delivery.awk" \
    "$scratch/graph" "$scratch/obligations" |
    awk -F '\t' '$1=="R" {sub(/^R\t/,"");print}' |
    LC_ALL=C sort -u > "$scratch/requests" || exit 2
  local check stage scope reference validation valid reason calls=0
  : > "$scratch/validated"
  while IFS=$'\t' read -r check stage scope reference; do
    [ -n "$check" ] || continue
    valid=false; reason=unavailable-evidence; calls=$((calls + 1))
    if validation=$(bash "$here/check-evidence.sh" validate-declared "$reference" "$check" "$stage" "$scope" "$worktree" 2> "$scratch/error"); then
      if [ "$(printf '%s\n' "$validation" | awk -F '\t' '$1=="valid" {print $2}')" = true ]; then valid=true; fi
    fi
    reason=$(printf '%s\n' "$validation" | awk -F '\t' '$1=="reason" {print $2}')
    printf 'V\t%s\t%s\t%s\t%s\t%s\t%s\n' "$check" "$stage" "$scope" "$reference" "$valid" "${reason:-unavailable-evidence}" >> "$scratch/validated"
  done < "$scratch/requests"
  printf 'metric\tevidence_validations\t%s\n' "$calls" >> "$scratch/validated"
  awk -F '\t' 'BEGIN {OFS="\t"}
    $1=="O" {scope[$2]=$4;next}
    $1=="check" && $8=="deferred" {print $4,$6,$7,($6 in scope ? scope[$6] : "-"),$10,$11}
  ' "$scratch/obligations" "$scratch/graph" | LC_ALL=C sort -u > "$scratch/deferrals"
  local wave authorization details config_cksum
  config_cksum=-
  if [ -f "$SIFT/config/config.yaml" ]; then config_cksum=$(cksum < "$SIFT/config/config.yaml") || exit 2; fi
  while IFS=$'\t' read -r wave check stage scope reference authorization; do
    [ -n "$wave" ] || continue
    valid=false; details=$'-\t-\t-\t-'
    if [ "$stage" = compatibility ] && [ "$authorization" = authorized-deferral ] && [ -f "$reference" ] && [ ! -L "$reference" ]; then
      if validation=$(SIFT_DEFER_RUN="$run" SIFT_DEFER_WAVE="$wave" SIFT_DEFER_CHECK="$check" \
        SIFT_DEFER_SCOPE="$scope" SIFT_DEFER_CONFIG="$config_cksum" LC_ALL=C \
        awk -f "$here/execution-deferral.awk" < "$reference"); then
        valid=true; details=$validation
      fi
    fi
    printf 'F\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$wave" "$check" "$stage" "$scope" "$reference" "$valid" "$details" >> "$scratch/validated"
  done < "$scratch/deferrals"
  LC_ALL=C awk -f "$here/execution-delivery.awk" "$scratch/graph" "$scratch/obligations" "$scratch/tickets" "$scratch/validated" | LC_ALL=C sort
)

report_obligations() {
  local here=$1 scratch=$2 id fields complete required stage scope good=1 count=0
  : > "$scratch/obligations"
  if ! LC_ALL=C awk -f "$here/execution-obligations.awk" "$SIFT/config/config.yaml" > "$scratch/check-ids"; then good=0; fi
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if fields=$(SIFT_CHECK_ID="$id" LC_ALL=C awk -f "$here/check-declaration.awk" "$SIFT/config/config.yaml"); then
      required=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="required" {print $2}')
      [ "$required" != false ] || continue
      complete=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="complete" {print $2}')
      stage=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="stage" {print $2}')
      scope=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="scope" {print $2}')
      if [ "$required" != true ] || [ "$complete" != true ]; then good=0; complete=incomplete; else complete=complete; fi
      case "$stage" in development|compatibility) ;; *) good=0; complete=incomplete ;; esac
      case "$scope" in ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*|[._-]*) good=0; complete=incomplete ;; esac
      printf 'O\t%s\t%s\t%s\t%s\n' "$id" "${stage:-unknown}" "${scope:-unknown}" "$complete" >> "$scratch/obligations"
      count=$((count + 1))
    else
      good=0
      printf 'diagnostic\tincomplete-declaration\t%s\n' "$id" >> "$scratch/obligations"
    fi
  done < "$scratch/check-ids"
  [ "$count" -gt 0 ] || good=0
  printf 'C\t%s\n' "$good" >> "$scratch/obligations"
  if [ "$good" -eq 0 ]; then printf 'diagnostic\tverification-unavailable\tcurrent-declarations\n' >> "$scratch/obligations"; fi
}

report_tickets() {
  local file id status base
  while IFS= read -r -d '' file; do
    id=$(fm_value "$file" id); status=$(fm_value "$file" status); base=${file##*/}
    case "$id" in "$PREFIX"-[0-9][0-9][0-9][0-9]*) ;; *) continue ;; esac
    case "${id#"$PREFIX"-}" in *[!0-9]*) continue ;; esac
    case "$base" in "$id"--*.md) ;; *) status=unknown ;; esac
    if ! awk '
      NR==1 {if($0!~/^---[[:space:]]*$/) exit 1; inside=1;next}
      inside && /^---[[:space:]]*$/ {closed=1;inside=0;next}
      inside && /^id:/ {ids++}
      inside && /^status:/ {statuses++}
      END {if(!closed || ids!=1 || statuses!=1) exit 1}
    ' "$file"; then status=unknown; fi
    case "$status" in open|in-progress|blocked|done|wontfix|superseded) ;; *) status=unknown ;; esac
    printf 'T\t%s\t%s\n' "$id" "$status"
  done < <(find "$SIFT/open" "$SIFT/archive" -type f -name "$PREFIX-*.md" -print0)
}
