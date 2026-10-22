#!/usr/bin/env bash
# Execute checks and validate immutable evidence against current declared inputs.
# stdout: evidence.md path for run; validated TSV decision for validate.
# run preserves the command exit status; setup/usage errors exit 2.
# validate exits 0 for matching complete passing evidence, 1 otherwise, 2 on usage.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
# shellcheck source=check-inputs.sh
. "$HERE/check-inputs.sh"
fail() { printf 'check-evidence: %s\n' "$*" >&2; exit 2; }
usage() {
  fail 'usage: check-evidence.sh [--] run RUN ATTEMPT CHECK STAGE SCOPE WORKTREE CWD -- COMMAND [ARG...]
       check-evidence.sh [--] validate EVIDENCE CHECK STAGE SCOPE WORKTREE CWD -- COMMAND [ARG...]
       check-evidence.sh [--] validate-declared EVIDENCE CHECK STAGE SCOPE WORKTREE'
}
[ "${1:-}" != -- ] || shift
MODE=${1:-}; [ "$#" -gt 0 ] || usage; shift
case "$MODE" in
  validate-declared)
    [ "$#" -eq 5 ] || usage
    EVIDENCE=$1; CHECK_ID=$2; STAGE=$3; SCOPE=$4; WORKTREE=$5
    check_id "$CHECK_ID" || usage
    DECLARED=$(SIFT_CHECK_ID="$CHECK_ID" LC_ALL=C awk -f "$HERE/check-declaration.awk" "$SIFT/config/config.yaml" 2>/dev/null) || {
      printf 'valid\tfalse\nreason\tincomplete-declaration\n'; exit 1;
    }
    DECLARED_ARGV=(); DECLARED_CWD=''
    while IFS=$'\t' read -r key value; do
      case "$key" in command) DECLARED_ARGV+=("$value") ;; cwd) DECLARED_CWD=$value ;; esac
    done <<< "$DECLARED"
    set -- "$CHECK_ID" "$STAGE" "$SCOPE" "$WORKTREE" "$DECLARED_CWD" -- "${DECLARED_ARGV[@]}"
    MODE=validate
    ;;
  run)
    [ "$#" -ge 9 ] || usage
    RUN=$1; ATTEMPT=$2; shift 2
    check_id "$RUN" && check_id "$ATTEMPT" || usage
    ;;
  validate)
    [ "$#" -ge 8 ] || usage
    EVIDENCE=$1; shift
    ;;
  *) usage ;;
esac
CHECK_ID=$1; STAGE=$2; SCOPE=$3; WORKTREE=$4; LOGICAL_CWD=$5; shift 5
[ "${1:-}" = -- ] || usage; shift
[ "$#" -gt 0 ] || usage
COMMAND=("$@")
check_id "$CHECK_ID" && check_id "$SCOPE" && check_relative "$LOGICAL_CWD" || usage
printf '%s\n' "$LOGICAL_CWD" | LC_ALL=C awk '/[^ -~]/ {exit 1}' || usage
case "$STAGE" in development|compatibility) ;; *) usage ;; esac
WORKTREE=$(cd "$WORKTREE" && pwd -P) || fail 'worktree unavailable'
[ -d "$WORKTREE/$LOGICAL_CWD" ] || fail 'working directory unavailable'
ROOT=$(cd "$ROOT" && pwd -P) || fail 'tracker root unavailable'
ARGV_HASH=$(printf '%s\0' "${COMMAND[@]}" | check_hash) || fail 'cannot fingerprint argv'

# Parse a whole record before exposing any fields. Metadata is bounded ASCII;
# arbitrary argv live separately as NUL-delimited bytes and are never evaluated.
record_valid() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  LC_ALL=C awk -F '\t' '
    NR==1 { if($0!="# Check evidence v1") bad=1; next }
    NR==2 { if($0!="") bad=1; next }
    {
      if(NF!=2 || $2=="" || $2 ~ /[^ -~]/ || seen[$1]++) bad=1
      value[$1]=$2
      if($1 !~ /^(run_id|attempt_id|check_id|stage|scope|cwd|exit_status|complete|stable|reason|before_hash|after_hash|argv_hash|log_hash)$/) bad=1
    }
    END {
      if(NR!=16 || bad) exit 1
      split("run_id attempt_id check_id scope",ids," ")
      for(i=1;i<=4;i++) if(value[ids[i]]!~/^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0-9][ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0-9_.-]*$/ || length(value[ids[i]])>128) exit 1
      if(value["stage"]!~/^(development|compatibility)$/ || value["exit_status"]!~/^(0|[1-9][0-9]*)$/ || value["exit_status"]+0>255) exit 1
      if(value["complete"]!~/^(true|false)$/ || value["stable"]!~/^(true|false)$/) exit 1
      split("before_hash after_hash argv_hash log_hash",hashes," ")
      for(i=1;i<=4;i++) if(value[hashes[i]]!~/^[0-9abcdef]+$/ || (length(value[hashes[i]])!=40 && length(value[hashes[i]])!=64)) exit 1
    }
  ' "$1"
}
# CURRENT is supplied by a fresh observation. No writes, commands or event trust.
validate_candidate() {
  local evidence=$1 dir file actual physical
  INVALID_REASON=missing-evidence
  record_valid "$evidence" || return 1
  dir=${evidence%/*}
  [ "$dir/evidence.md" = "$evidence" ] || return 1
  case "$dir" in /*) ;; *) return 1 ;; esac
  physical=$(cd "$dir" && pwd -P) || return 1
  case "$physical/" in "$ROOT/"*|"$WORKTREE/"*) return 1 ;; esac
  for file in before.manifest after.manifest argv.nul raw.log; do
    [ -f "$dir/$file" ] && [ ! -L "$dir/$file" ] || return 1
  done
  for file in before after argv log; do
    case "$file" in before|after) actual="$dir/$file.manifest" ;; argv) actual="$dir/argv.nul" ;; log) actual="$dir/raw.log" ;; esac
    actual=$(check_hash < "$actual") || return 1
    [ "$actual" = "$(check_field "$evidence" "${file}_hash")" ] || return 1
  done
  INVALID_REASON=failed-evidence
  [ "$(check_field "$evidence" exit_status)" = 0 ] || return 1
  INVALID_REASON=unstable-inputs
  [ "$(check_field "$evidence" stable)" = true ] && cmp -s "$dir/before.manifest" "$dir/after.manifest" || return 1
  INVALID_REASON=incomplete-declaration
  [ "$(check_field "$evidence" complete)" = true ] &&
    [ "$(check_field "$dir/before.manifest" complete)" = true ] || return 1
  INVALID_REASON=changed-inputs
  [ "$(check_field "$evidence" check_id)" = "$CHECK_ID" ] &&
    [ "$(check_field "$evidence" stage)" = "$STAGE" ] &&
    [ "$(check_field "$evidence" scope)" = "$SCOPE" ] &&
    [ "$(check_field "$evidence" cwd)" = "$LOGICAL_CWD" ] &&
    [ "$(check_field "$evidence" argv_hash)" = "$ARGV_HASH" ] &&
    [ "$(check_field "$evidence" before_hash)" = "$CURRENT_HASH" ] || return 1
  INVALID_REASON=unchanged-inputs
}
observe() {
  CURRENT=$(check_snapshot) || fail 'cannot observe inputs'
  CURRENT_HASH=$(printf '%s\n' "$CURRENT" | check_hash) || fail 'cannot fingerprint inputs'
}
report_validation() {
  printf 'valid\t%s\nreason\t%s\n' "$1" "$2"
  if [ "$1" = true ]; then
    printf 'producing_run\t%s\nproducing_attempt\t%s\n' "$(check_field "$EVIDENCE" run_id)" "$(check_field "$EVIDENCE" attempt_id)"
  fi
}
observe
if [ "$MODE" = validate ]; then
  if [ "$(check_text_field "$CURRENT" complete)" != true ]; then
    report_validation false "$(check_text_field "$CURRENT" reason)"; exit 1
  fi
  if validate_candidate "$EVIDENCE"; then
    FIRST_HASH=$CURRENT_HASH
    observe
    if [ "$FIRST_HASH" = "$CURRENT_HASH" ]; then report_validation true unchanged-inputs; exit 0; fi
    INVALID_REASON=unstable-inputs
  fi
  report_validation false "$INVALID_REASON"; exit 1
fi

# Resolve the store physically before writing: aliases into either checkout fail.
STORE=${SIFT_EVIDENCE_DIR:-${TMPDIR:-/tmp}/sift-check-evidence}
case "$STORE" in /*) ;; *) fail 'SIFT_EVIDENCE_DIR must be absolute' ;; esac
# Require a pre-existing parent so the guard runs before mkdir.
PARENT=$(cd "$(dirname "$STORE")" && pwd -P) || fail 'evidence parent unavailable'
STORE="$PARENT/$(basename "$STORE")"
if [ -d "$STORE" ]; then STORE=$(cd "$STORE" && pwd -P) || fail 'evidence store unavailable'; fi
case "$STORE/" in "$ROOT/"*|"$WORKTREE/"*) fail 'evidence must live outside both checkouts' ;; esac
mkdir -p "$STORE" || fail 'cannot create evidence store'
# Task 1 owns the only event writer. All correlation is passed explicitly.
event() { bash "$HERE/drain-log.sh" event "$1" "run_id=$RUN" "attempt_id=$ATTEMPT" actor=helper "${@:2}"; }
REASON=no-prior-evidence
if [ "$(check_text_field "$CURRENT" complete)" = true ]; then
  for candidate in "$STORE"/check.*/evidence.md; do
    [ -f "$candidate" ] || continue
    # Unrelated obligations do not obscure a useful invalidation reason.
    [ "$(check_field "$candidate" check_id)" = "$CHECK_ID" ] || continue
    if validate_candidate "$candidate"; then
      FIRST_HASH=$CURRENT_HASH
      observe
      if [ "$FIRST_HASH" = "$CURRENT_HASH" ]; then
        event check "check_id=$CHECK_ID" "stage=$STAGE" outcome=reused reason=unchanged-inputs "evidence_ref=$candidate" >/dev/null || fail 'cannot publish reuse'
        printf '%s\n' "$candidate"; exit 0
      fi
      REASON=unstable-inputs
      break
    else
      REASON=$INVALID_REASON
    fi
  done
else
  REASON=$(check_text_field "$CURRENT" reason)
fi
DIR=$(umask 077; mktemp -d "$STORE/check.XXXXXXXXXX") || fail 'cannot reserve evidence'
EVIDENCE="$DIR/evidence.md"
printf '%s\0' "${COMMAND[@]}" > "$DIR/argv.nul" || fail 'cannot save argv'
printf '%s\n' "$CURRENT" > "$DIR/before.manifest" || fail 'cannot save inputs'
event check "check_id=$CHECK_ID" "stage=$STAGE" outcome=invalidated reason=other "reason_detail=$REASON" "evidence_ref=$EVIDENCE" >/dev/null || fail 'cannot publish decision'
START=$(date +%s) || fail 'cannot read clock'
SPAN=$(event span-start activity=verification "timestamp=$START") || fail 'cannot publish start'
SPAN_ID=$(bash "$HERE/drain-log.sh" event-fields "$SPAN" | awk -F '\t' '$1=="span_id" {print $2}') || fail 'cannot read span'
if (cd "$WORKTREE/$LOGICAL_CWD" && "${COMMAND[@]}") > "$DIR/raw.log" 2>&1; then STATUS=0; else STATUS=$?; fi
clock_gap() {
  printf 'check-evidence: instrumentation gap: %s; span %s remains incomplete; evidence retained at %s\n' \
    "$1" "$SPAN_ID" "$EVIDENCE" >&2
}
# Preserve the command status even if later diagnostic publication fails.
finish() {
  local after after_hash complete stable outcome end duration
  after=$(check_snapshot) || return 1
  printf '%s\n' "$after" > "$DIR/after.manifest" || return 1
  after_hash=$(check_hash < "$DIR/after.manifest") || return 1
  complete=$(check_text_field "$CURRENT" complete)
  stable=false; [ "$CURRENT_HASH" != "$after_hash" ] || stable=true
  if [ "$stable" = false ]; then REASON=unstable-inputs; fi
  {
    printf '# Check evidence v1\n\n'
    printf 'run_id\t%s\nattempt_id\t%s\ncheck_id\t%s\nstage\t%s\nscope\t%s\ncwd\t%s\n' "$RUN" "$ATTEMPT" "$CHECK_ID" "$STAGE" "$SCOPE" "$LOGICAL_CWD"
    printf 'exit_status\t%s\ncomplete\t%s\nstable\t%s\nreason\t%s\n' "$STATUS" "$complete" "$stable" "$REASON"
    printf 'before_hash\t%s\nafter_hash\t%s\nargv_hash\t%s\nlog_hash\t%s\n' "$CURRENT_HASH" "$after_hash" "$ARGV_HASH" "$(check_hash < "$DIR/raw.log")"
  } > "$DIR/evidence.pending" || return 1
  record_valid "$DIR/evidence.pending" || return 1
  mv "$DIR/evidence.pending" "$EVIDENCE" || return 1
  outcome=failed; [ "$STATUS" -ne 0 ] || outcome=passed
  if ! end=$(date +%s 2>/dev/null); then
    clock_gap 'end clock unavailable'; return 1
  fi
  # Match the public timestamp grammar before arithmetic, which evaluates names
  # and treats leading zeroes as octal. START was validated by span publication.
  case "$end" in
    ''|*[!0-9]*|0?*) clock_gap 'end clock malformed'; return 1 ;;
  esac
  if [ "${#end}" -gt 15 ]; then
    clock_gap 'end clock malformed'; return 1
  fi
  if [ "$end" -lt "$START" ]; then
    clock_gap "end clock moved backwards (start=$START end=$end)"; return 1
  fi
  duration=$((end - START))
  event span-end "span_id=$SPAN_ID" "duration=$duration" "timestamp=$end" "outcome=$outcome" >/dev/null || return 1
  event check "check_id=$CHECK_ID" "stage=$STAGE" "outcome=$outcome" "exit_status=$STATUS" "evidence_ref=$EVIDENCE" >/dev/null || return 1
  printf '%s\n' "$EVIDENCE"
}
if ! finish; then
  printf 'check-evidence: diagnostic publication failed; command exit %s; retained %s\n' "$STATUS" "$DIR" >&2
  [ "$STATUS" -ne 0 ] || exit 2
fi
exit "$STATUS"
