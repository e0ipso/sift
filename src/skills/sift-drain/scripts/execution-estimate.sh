#!/usr/bin/env bash
# Bounded ETA observations. Only explicit estimate requests publish records.
eta_error() { printf 'error: estimate: %s\n' "$*" >&2; return 2; }
eta_hash() { cksum < "$1" | awk '{print $1 ":" $2}'; }
eta_field() { ETA_KEY="$2" awk -F '\t' '$1=="estimate" && $2==ENVIRON["ETA_KEY"] {print $3}' "$1"; }

estimate_main() (
  local mode=$1
  shift
  local run=${1:-} now worktree declaration reason here scratch base dir record previous=- heads=0
  local graph_hash input_hash id lower origin
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 2
  if [ "$mode" = estimate ]; then
    [ "$#" -ge 4 ] && [ "$#" -le 5 ] || usage
    worktree=$2; declaration=$3; now=$4; reason=${5:-changed-evidence-or-scope}
    [ -f "$declaration" ] || { eta_error 'missing declaration'; exit 2; }
    worktree=$(cd "$worktree" && pwd -P) || exit 2
  else
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
    now=${2:-}; worktree=$ROOT
    if [ "$#" -lt 2 ]; then now=$(date +%s) || exit 2; fi
  fi
  ETA_RUN="$run" ETA_NOW="$now" ETA_REASON="${reason:-render}" LC_ALL=C awk 'BEGIN {
    r=ENVIRON["ETA_RUN"]; t=ENVIRON["ETA_NOW"]; s=ENVIRON["ETA_REASON"]
    exit !(r ~ /^[[:alnum:]][[:alnum:]_.-]*$/ && length(r)<=128 &&
      t ~ /^(0|[1-9][0-9]*)$/ && length(t)<=15 && length(s)>0 && length(s)<=4096 && s !~ /[^[:print:]]/)
  }' || { eta_error 'invalid run, epoch or revision reason'; exit 2; }
  [ -d "$SIFT/runs/$run/events" ] || { eta_error 'run has no events'; exit 2; }
  base=$(cd "${TMPDIR:-/tmp}" && pwd -P) || exit 2
  case "$base/" in "$ROOT/"*|"$worktree/"*) base=/tmp ;; esac
  scratch=$(mktemp -d "$base/sift-estimate.XXXXXXXXXX") || exit 2
  trap 'rm -rf "$scratch"' EXIT
  : > "$scratch/history"
  for dir in "$SIFT/runs/$run/estimates"/*; do
    [ -d "$dir" ] || continue
    record="$dir/estimate.md"
    if [ ! -f "$record" ]; then
      printf 'estimate diagnostic: incomplete publication %s\n' "${dir##*/}" >&2
      continue
    fi
    [ ! -L "$dir" ] && [ ! -L "$record" ] &&
      [ -f "$dir/snapshot.tsv" ] && [ ! -L "$dir/snapshot.tsv" ] &&
      [ -f "$dir/observations.tsv" ] && [ ! -L "$dir/observations.tsv" ] || {
      eta_error "invalid publication: $dir"; exit 2;
    }
    ETA_ID="${dir##*/}" ETA_RUN="$run" LC_ALL=C awk -f "$here/estimate-record.awk" "$record" || exit 2
    [ "$(eta_field "$record" graph_fingerprint)" = "$(eta_hash "$dir/snapshot.tsv")" ] &&
      [ "$(eta_field "$record" input_fingerprint)" = "$(eta_hash "$dir/observations.tsv")" ] || {
      eta_error "changed snapshot/observations: $dir"; exit 2;
    }
    printf '%s\t%s\n' "${dir##*/}" "$(eta_field "$record" previous)" >> "$scratch/history"
  done
  # History is a linked DAG, never a mutable current pointer or timestamp sort.
  awk -F '\t' '{seen[$1]=1; parent[$1]=$2; if($2!="-") used[$2]=1}
    END {for(i in parent) {
        if(parent[i]!="-" && !(parent[i] in seen)) exit 2
        p=i; steps=0
        while(p!="-") {if(++steps>NR) exit 2; p=parent[p]}
      }
      for(i in seen) if(!(i in used)) print i}' "$scratch/history" > "$scratch/heads" || {
    eta_error 'missing previous estimate or cyclic history'; exit 2;
  }
  while IFS= read -r id; do previous=$id; heads=$((heads+1)); done < "$scratch/heads"
  if [ "$heads" -gt 1 ] || { [ -s "$scratch/history" ] && [ "$heads" -eq 0 ]; }; then
    eta_error 'ambiguous or cyclic estimate history; inspect concurrent coordinator publications'; exit 2
  fi
  if [ "$mode" = report-estimate ]; then
    if [ "$previous" = - ]; then printf 'estimate\tstatus\tunavailable\ndiagnostic\tno-recorded-estimate\trun\n'; exit 0; fi
    record="$SIFT/runs/$run/estimates/$previous/estimate.md"
    origin=$(eta_field "$record" origin_epoch)
    [ "$now" -ge "$origin" ] || { eta_error 'observation precedes estimate origin'; exit 2; }
    sed '1,2d' "$record"
    lower=$(eta_field "$record" lower_epoch)
    if [ "$lower" = - ]; then printf 'estimate\tlower_bound_state\tunavailable\n'
    elif [ "$now" -gt "$lower" ]; then printf 'estimate\tlower_bound_state\tpassed\n'
    else printf 'estimate\tlower_bound_state\tnot-passed\n'; fi
    exit 0
  fi
  LC_ALL=C sort "$declaration" > "$scratch/snapshot.tsv" || exit 2
  report_events "$run" "$worktree" "$now" > "$scratch/report" || exit 2
  if ! awk -F '\t' '$1=="diagnostic" && $2=="after-observation" {bad=1} END {exit bad}' "$scratch/report"; then
    eta_error 'observation precedes recorded events'; exit 2
  fi
  # Stable report rows retain identities, measured intervals and current delivery.
  # Observation-derived ages/windows/counters never invalidate an origin.
  awk -F '\t' '
    $1=="metric" {if($2=="report_version" || $2=="integrity_errors") print; next}
    $1=="wave-metric" {if($3=="throughput_numerator_tickets") print; next}
    {print}
  ' "$scratch/report" > "$scratch/observations.tsv" || exit 2
  graph_hash=$(eta_hash "$scratch/snapshot.tsv") || exit 2
  input_hash=$(eta_hash "$scratch/observations.tsv") || exit 2
  if [ "$previous" != - ]; then
    record="$SIFT/runs/$run/estimates/$previous/estimate.md"
    origin=$(eta_field "$record" origin_epoch)
    [ "$now" -ge "$origin" ] || { eta_error 'request precedes previous origin'; exit 2; }
    if [ "$graph_hash" = "$(eta_field "$record" graph_fingerprint)" ] &&
      [ "$input_hash" = "$(eta_field "$record" input_fingerprint)" ]; then
      printf '%s\n' "$record"; exit 0
    fi
  else reason=initial-observation; fi
  ETA_NOW="$now" ETA_PREFIX="$PREFIX" LC_ALL=C awk -f "$here/execution-estimate.awk" \
    "$scratch/snapshot.tsv" "$scratch/observations.tsv" > "$scratch/result" || exit 2
  mkdir -p "$SIFT/runs/$run/estimates" || exit 2
  dir=$(mktemp -d "$SIFT/runs/$run/estimates/estimate.XXXXXXXXXX") || exit 2
  id=${dir##*/}
  cp "$scratch/snapshot.tsv" "$dir/snapshot.tsv" &&
    cp "$scratch/observations.tsv" "$dir/observations.tsv" || exit 2
  {
    printf '# Execution estimate v1\n\n'
    printf 'estimate\tid\t%s\nestimate\trun_id\t%s\nestimate\torigin_epoch\t%s\n' "$id" "$run" "$now"
    printf 'estimate\tprevious\t%s\nestimate\trevision_reason\t%s\n' "$previous" "$reason"
    printf 'estimate\tgraph_fingerprint\t%s\nestimate\tinput_fingerprint\t%s\n' "$graph_hash" "$input_hash"
    cat "$scratch/result"
  } > "$dir/estimate.pending" || exit 2
  ETA_ID="$id" ETA_RUN="$run" LC_ALL=C awk -f "$here/estimate-record.awk" "$dir/estimate.pending" || exit 2
  mv "$dir/estimate.pending" "$dir/estimate.md" || exit 2
  printf '%s\n' "$dir/estimate.md"
)
