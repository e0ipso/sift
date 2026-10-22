#!/usr/bin/env bash
# Review isolation state and narrow immutable-event publication allowances.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

REVIEW_STATE="$REPO_ROOT/src/skills/sift-drain/scripts/review-state.sh"
DRAINLOG="$REPO_ROOT/src/skills/sift-drain/scripts/drain-log.sh"

review_fixture() {
  local d
  d="$(newdir)"
  git -C "$d" init -q
  printf 'code\n' > "$d/code.txt"
  git -C "$d" add code.txt
  git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm initial
  git -C "$d" branch -M main
  mkdir -p "$d/.ai/sift/open" "$d/.ai/sift/archive" "$d/.ai/sift/config"
  printf 'prefix: SFT\n' > "$d/.ai/sift/config/config.yaml"
  printf '.ai/\n' > "$d/.git/info/exclude"
  printf '%s\n' "$d"
}

take_snapshot() {
  local root output
  root="$1"; output="$2"
  run_cmd "$root" env SIFT_ROOT="$root" "$REVIEW_STATE" snapshot
  assert_eq 0 "$R_STATUS" "snapshot succeeds"
  assert_contains "$R_OUT" '@tracker' "snapshot includes its tracker boundary"
  printf '%s\n' "$R_OUT" > "$output"
}

publish_event() {
  env SIFT_ROOT="$1" "$DRAINLOG" event run-start run_id=run-review \
    actor=coordinator timestamp=1000
}

test_case "an exact newly published and validated event is the only allowed tracker delta"
d="$(review_fixture)"
states="$(newdir)"
take_snapshot "$d" "$states/before"
record="$(publish_event "$d")"
take_snapshot "$d" "$states/after"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "the valid event is forbidden until its exact receipt is authorized"
assert_contains "$R_ERR" "${record#"$d/"}" "the unauthorized diagnostic path is named"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after" \
  --allow-event "$record"
assert_eq 0 "$R_STATUS" "the exact validated new event is allowed"
assert_eq '' "$R_OUT$R_ERR" "an allowed publication needs no exception report"

test_case "authorization never permits changed or deleted historical diagnostic bytes"
d="$(review_fixture)"
states="$(newdir)"
record="$(publish_event "$d")"
take_snapshot "$d" "$states/before"
printf '\n' >> "$record"
take_snapshot "$d" "$states/changed"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/changed" \
  --allow-event "$record"
assert_eq 1 "$R_STATUS" "authorization cannot excuse a changed historical event"
assert_contains "$R_ERR" 'changed historical tracker file' "the historical-byte violation is explicit"

d="$(review_fixture)"
states="$(newdir)"
record="$(publish_event "$d")"
relative_record="${record#"$d/"}"
take_snapshot "$d" "$states/before"
rm "$record"
take_snapshot "$d" "$states/deleted"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/deleted" \
  --allow-event "$relative_record"
assert_eq 1 "$R_STATUS" "authorization cannot excuse a deleted historical event"
assert_contains "$R_ERR" 'deleted historical tracker file' "the deleted record is diagnosed"

test_case "a shaped authorization still requires a valid event with matching path identities"
d="$(review_fixture)"
states="$(newdir)"
take_snapshot "$d" "$states/before"
fake="$d/.ai/sift/runs/run-review/events/event.fake/event.md"
mkdir -p "${fake%/*}"
printf 'not an execution event\n' > "$fake"
take_snapshot "$d" "$states/after"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after" \
  --allow-event "$fake"
assert_eq 1 "$R_STATUS" "an invalid event cannot use the publication allowance"
assert_contains "$R_ERR" 'authorized event is invalid' "validation failure is reported"

test_case "ticket, config, reservation, legacy-log and pending-event additions stay forbidden"
for mutation in ticket config reservation legacy pending; do
  d="$(review_fixture)"
  states="$(newdir)"
  take_snapshot "$d" "$states/before"
  case "$mutation" in
    ticket)
      mkdir -p "$d/.ai/sift/open/foundation/feature"
      changed="$d/.ai/sift/open/foundation/feature/SFT-0001--review-write.md"
      printf 'ticket\n' > "$changed"
      ;;
    config)
      changed="$d/.ai/sift/config/review-write"
      printf 'config\n' > "$changed"
      ;;
    reservation)
      mkdir -p "$d/.ai/sift/.id-sequence"
      changed="$d/.ai/sift/.id-sequence/SFT-0001"
      printf 'reservation\n' > "$changed"
      ;;
    legacy)
      changed="$d/.ai/sift/RUNLOG.md"
      printf '# Run log\n' > "$changed"
      ;;
    pending)
      changed="$d/.ai/sift/runs/run-review/events/event.pending/event.pending"
      mkdir -p "${changed%/*}"
      printf 'pending\n' > "$changed"
      ;;
  esac
  take_snapshot "$d" "$states/after"
  assert_file "$changed" "$mutation positive control reaches the tracker"
  run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
  assert_eq 1 "$R_STATUS" "$mutation addition is rejected"
  assert_contains "$R_ERR" "${changed#"$d/"}" "$mutation diagnostic names the added path"
done

test_case "integration Git state changes remain review violations"
d="$(review_fixture)"
states="$(newdir)"
take_snapshot "$d" "$states/before"
printf 'changed\n' > "$d/code.txt"
take_snapshot "$d" "$states/after"
assert_eq changed "$(cat "$d/code.txt")" "the positive control changes a tracked integration file"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a tracked integration edit is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the Git-state violation is explicit"

summary
