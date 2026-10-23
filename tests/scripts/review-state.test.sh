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

commit_with_tree() {
  local root="$1" tree="$2" parent
  parent="$(git -C "$root" rev-parse HEAD)"
  git -C "$root" -c user.name=Fixture -c user.email=fixture@example.invalid \
    commit-tree "$tree" -p "$parent" -m 'review-state fixture'
}

same_tree_commit() {
  commit_with_tree "$1" "$(git -C "$1" rev-parse 'HEAD^{tree}')"
}

different_tree_commit() {
  local root="$1" blob tree
  blob="$(printf 'other\n' | git -C "$root" hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tcode.txt\n' "$blob" | git -C "$root" mktree)"
  commit_with_tree "$root" "$tree"
}

insert_section_line() {
  local file="$1"
  SIFT_REVIEW_MARKER="$2" SIFT_REVIEW_LINE="$3" awk '
    BEGIN { marker = ENVIRON["SIFT_REVIEW_MARKER"]; line = ENVIRON["SIFT_REVIEW_LINE"] }
    { print }
    $0 == marker { print line }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
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

test_case "a new ref whose commit tree matches the snapshot HEAD is not a review violation"
d="$(review_fixture)"
states="$(newdir)"
head="$(git -C "$d" rev-parse HEAD)"
tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
take_snapshot "$d" "$states/before"
commit="$(same_tree_commit "$d")"
assert_ne "$head" "$commit" "the same-tree bookmark is a different commit"
assert_eq "$tree" "$(git -C "$d" rev-parse "$commit^{tree}")" "the bookmark stores the snapshot HEAD tree"
git -C "$d" update-ref refs/bookmarks/same-tree "$commit"
assert_eq '' "$(git -C "$d" status --porcelain)" "the same-tree ref leaves status empty"
assert_eq '' "$(git -C "$d" diff HEAD)" "the same-tree ref leaves the HEAD diff empty"
assert_eq "$head" "$(git -C "$d" rev-parse HEAD)" "HEAD stays on the recorded commit"
take_snapshot "$d" "$states/after"
ref_line="$(printf '%s commit\trefs/bookmarks/same-tree' "$commit")"
assert_contains "$(cat "$states/after")" "$ref_line" "the snapshot still records the new ref"
assert_not_contains "$(cat "$states/before")" 'refs/bookmarks/same-tree' "the before snapshot lacks that ref"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 0 "$R_STATUS" "a same-tree ref is not a review violation"
assert_eq '' "$R_OUT$R_ERR" "a same-tree ref needs no exception report"

test_case "a same-tree ref under refs/t3/orchestration-v2/checkpoints is not a review violation"
d="$(review_fixture)"
states="$(newdir)"
head="$(git -C "$d" rev-parse HEAD)"
tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
take_snapshot "$d" "$states/before"
commit="$(same_tree_commit "$d")"
assert_eq "$tree" "$(git -C "$d" rev-parse "$commit^{tree}")" "the checkpoint commit stores the snapshot HEAD tree"
git -C "$d" update-ref refs/t3/orchestration-v2/checkpoints/same-tree/ordinal/4 "$commit"
assert_eq "$head" "$(git -C "$d" rev-parse HEAD)" "a checkpoint ref does not move HEAD"
take_snapshot "$d" "$states/after"
ref_line="$(printf '%s commit\trefs/t3/orchestration-v2/checkpoints/same-tree/ordinal/4' "$commit")"
assert_contains "$(cat "$states/after")" "$ref_line" "the snapshot still records the checkpoint ref"
assert_not_contains "$(cat "$states/before")" 'refs/t3/orchestration-v2/checkpoints/same-tree/ordinal/4' \
  "the before snapshot lacks that checkpoint ref"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 0 "$R_STATUS" "a same-tree checkpoint ref is not a review violation"
assert_eq '' "$R_OUT$R_ERR" "a same-tree checkpoint ref needs no exception report"

test_case "a new branch ref whose tree differs from the snapshot HEAD fails review"
d="$(review_fixture)"
states="$(newdir)"
head="$(git -C "$d" rev-parse HEAD)"
tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
take_snapshot "$d" "$states/before"
commit="$(different_tree_commit "$d")"
assert_ne "$tree" "$(git -C "$d" rev-parse "$commit^{tree}")" "the branch commit stores another tree"
git -C "$d" update-ref refs/heads/other-tree "$commit"
assert_eq "$head" "$(git -C "$d" rev-parse HEAD)" "the other branch does not move HEAD"
take_snapshot "$d" "$states/after"
assert_contains "$(cat "$states/after")" 'refs/heads/other-tree' "the snapshot records the other branch"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a branch with another tree is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the other branch is a Git-state violation"

test_case "a refs/t3 ref whose tree differs from the snapshot HEAD fails review"
d="$(review_fixture)"
states="$(newdir)"
head="$(git -C "$d" rev-parse HEAD)"
tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
take_snapshot "$d" "$states/before"
commit="$(different_tree_commit "$d")"
assert_ne "$tree" "$(git -C "$d" rev-parse "$commit^{tree}")" "the checkpoint commit stores another tree"
git -C "$d" update-ref refs/t3/orchestration-v2/checkpoints/other-tree/ordinal/0 "$commit"
assert_eq "$head" "$(git -C "$d" rev-parse HEAD)" "a differing checkpoint ref does not move HEAD"
take_snapshot "$d" "$states/after"
assert_contains "$(cat "$states/after")" \
  'refs/t3/orchestration-v2/checkpoints/other-tree/ordinal/0' \
  "the snapshot records the differing checkpoint ref"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a checkpoint ref with another tree is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the differing checkpoint is a Git-state violation"

test_case "a new HEAD commit fails review even when its tree is unchanged"
d="$(review_fixture)"
states="$(newdir)"
before_head="$(git -C "$d" rev-parse HEAD)"
before_tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
take_snapshot "$d" "$states/before"
git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid \
  commit -q --allow-empty -m 'same tree'
after_head="$(git -C "$d" rev-parse HEAD)"
after_tree="$(git -C "$d" rev-parse 'HEAD^{tree}')"
assert_ne "$before_head" "$after_head" "the empty commit moves HEAD"
assert_eq "$before_tree" "$after_tree" "the empty commit keeps the same tree"
assert_eq '' "$(git -C "$d" status --porcelain)" "the empty commit leaves status empty"
assert_eq '' "$(git -C "$d" diff HEAD)" "the empty commit leaves the HEAD diff empty"
take_snapshot "$d" "$states/after"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a new HEAD commit is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the moved HEAD is a Git-state violation"

test_case "a new ref that names a missing object fails review"
d="$(review_fixture)"
states="$(newdir)"
missing='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
take_snapshot "$d" "$states/before"
git -C "$d" cat-file -e "$missing" >/dev/null 2>&1
missing_status=$?
assert_ne 0 "$missing_status" "the named object is absent from the fixture"
cp "$states/before" "$states/after"
missing_line="$(printf '%s commit\trefs/missing/gone' "$missing")"
insert_section_line "$states/after" '@git-refs' "$missing_line"
assert_contains "$(cat "$states/after")" "$missing_line" "the after snapshot lists the missing ref"
assert_not_contains "$(cat "$states/before")" 'refs/missing/gone' "the before snapshot lacks that ref"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a ref to a missing object is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the missing object is a Git-state violation"

test_case "a new ref whose object is not a commit fails review"
d="$(review_fixture)"
states="$(newdir)"
take_snapshot "$d" "$states/before"
blob="$(printf 'not a commit\n' | git -C "$d" hash-object -w --stdin)"
assert_eq blob "$(git -C "$d" cat-file -t "$blob")" "the new object is a blob"
git -C "$d" update-ref refs/notes/review-blob "$blob"
take_snapshot "$d" "$states/after"
assert_contains "$(cat "$states/after")" "$(printf '%s blob\trefs/notes/review-blob' "$blob")" \
  "the snapshot records the blob ref"
run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
assert_eq 1 "$R_STATUS" "a non-commit ref is rejected"
assert_contains "$R_ERR" 'integration Git state changed' "the blob ref is a Git-state violation"

test_case "status, diff, stash, untracked, and tracker differences still fail review"
for kind in status diff stash untracked tracker; do
  d="$(review_fixture)"
  states="$(newdir)"
  take_snapshot "$d" "$states/before"
  cp "$states/before" "$states/after"
  case "$kind" in
    status)
      marker='@git-status'
      line=' M synthetic-status.txt'
      needle='integration Git state changed'
      ;;
    diff)
      marker='@git-diff'
      line='9999999999 1 synthetic.diff'
      needle='integration Git state changed'
      ;;
    stash)
      marker='@git-stashes'
      line='stash@{0}: synthetic review marker'
      needle='integration Git state changed'
      ;;
    untracked)
      marker='@git-untracked'
      line='1 1 synthetic-untracked.txt'
      needle='integration Git state changed'
      ;;
    tracker)
      marker='@tracker'
      line='1 1 .ai/sift/open/extra.md'
      needle='unauthorized tracker addition'
      ;;
  esac
  insert_section_line "$states/after" "$marker" "$line"
  assert_contains "$(cat "$states/after")" "$line" "$kind difference is present in the after snapshot"
  assert_not_contains "$(cat "$states/before")" "$line" "$kind difference is absent from the before snapshot"
  run_cmd "$d" env SIFT_ROOT="$d" "$REVIEW_STATE" compare "$states/before" "$states/after"
  assert_eq 1 "$R_STATUS" "$kind difference is rejected"
  assert_contains "$R_ERR" "$needle" "$kind difference names its violation"
done

summary
