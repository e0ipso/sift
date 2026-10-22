#!/usr/bin/env bash
# Every gate prompt carries its own operating and ownership rules. Gate agents
# return commits and defect reports; the drain orchestrator alone merges and
# writes tracker state (SFT-0103, SFT-0107).

set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
. "$repo/tests/lib/harness.sh"

gate_prompt() {
  awk -v want="$2" '
    $0 == want { section = 1; next }
    section && /^## / { exit }
    section && /^```$/ { if (inside) exit; inside = 1; next }
    section && inside { print }
  ' "$1"
}

contract_errors() {
  local file="$1" heading prompt flattened without_bans
  for heading in \
    '## 1. E2E specialist agent' \
    '## 2. Batch coverage agent' \
    '## 3. Root-cause fixes' \
    '## 4. Wave knowledge capture'
  do
    prompt="$(gate_prompt "$file" "$heading")"
    [ -n "$prompt" ] || { printf '%s: missing prompt\n' "$heading"; continue; }
    flattened="$(printf '%s\n' "$prompt" | tr '\n' ' ')"
    printf '%s\n' "$flattened" | grep -Fq 'Verify every named path' ||
      printf '%s: does not require live path verification\n' "$heading"
    printf '%s\n' "$flattened" | grep -Fq 'Use the prepared worktree' ||
      printf '%s: does not use the prepared worktree\n' "$heading"
    printf '%s\n' "$flattened" | grep -Eiq 'commit your scoped changes|commit the scoped changes' ||
      printf '%s: does not require a commit\n' "$heading"
    printf '%s\n' "$prompt" | grep -Fq 'commit: <hash>' ||
      printf '%s: does not report the commit\n' "$heading"
    printf '%s\n' "$flattened" | grep -Eiq 'do not merge' ||
      printf '%s: does not prohibit merging\n' "$heading"
    printf '%s\n' "$flattened" | grep -Eiq 'never `git push`' ||
      printf '%s: does not prohibit git push\n' "$heading"
    printf '%s\n' "$flattened" | grep -Fq 'Do not write tracker state' ||
      printf '%s: does not reserve tracker writes for the orchestrator\n' "$heading"
    printf '%s\n' "$flattened" | grep -Eiq '(do not|never) edit the sift-drain skill' ||
      printf '%s: does not protect the sift-drain skill\n' "$heading"
    printf '%s\n' "$flattened" | grep -Eiq '(do not|never) file, comment on, or patch an external tracker' ||
      printf '%s: does not prohibit external tracker writes\n' "$heading"
    printf '%s\n' "$flattened" | grep -Fq 'type: dx' ||
      printf '%s: does not route upstream proposals to the orchestrator\n' "$heading"
    case "$heading" in
      '## 4. Wave knowledge capture') ;;
      *) printf '%s\n' "$flattened" | grep -Fq 'Do not capture durable knowledge' ||
           printf '%s: does not defer durable knowledge capture\n' "$heading" ;;
    esac
    # The required bans above match case-insensitively, so the exemptions must
    # too: lowercase the prompt once, then strip the lowercase ban phrases.
    # `has merged` is the one descriptive use a prompt makes of the word.
    without_bans="$(printf '%s\n' "$flattened" | tr '[:upper:]' '[:lower:]' | sed \
      -e 's/do not merge//g' \
      -e 's/has merged//g' \
      -e 's/do not write tracker state//g')"
    if printf '%s\n' "$without_bans" | grep -Eq '(^|[^[:alnum:]_])merg(e|es|ed|ing)([^[:alnum:]_]|$)'; then
      printf '%s: assigns a merge to the gate agent\n' "$heading"
    fi
    if printf '%s\n' "$without_bans" | grep -Eq 'roadmap\.md|file a sift ticket|tickets filed:|write tracker state'; then
      printf '%s: assigns tracker state to the gate agent\n' "$heading"
    fi
  done
}

test_case "all four gate templates carry their actor-local ownership rules"
errors="$(contract_errors "$repo/src/skills/sift-drain/references/wave-gate.md")"
assert_eq "" "$errors" "every ownership rule remains inside the dispatched prompt"

# Prove both negative arms against each prompt. The injected imperatives are
# deliberately plain so the pin rejects the exact regression it documents.
for heading in \
  '## 1. E2E specialist agent' \
  '## 2. Batch coverage agent' \
  '## 3. Root-cause fixes' \
  '## 4. Wave knowledge capture'
do
  for damage in 'Merge the branch before reporting.' 'Write tracker state before reporting.'; do
    test_case "$heading rejects: $damage"
    damaged="$(newdir)/wave-gate.md"
    awk -v want="$heading" -v damage="$damage" '
      $0 == want { section = 1 }
      section && !inserted && /^```$/ { print; print damage; inserted = 1; next }
      { print }
    ' "$repo/src/skills/sift-drain/references/wave-gate.md" > "$damaged"
    errors="$(contract_errors "$damaged")"
    assert_contains "$errors" "$heading" "the damaged template is named"
    case "$damage" in
      *Merge*|*merge*) assert_contains "$errors" 'assigns a merge' "the merge instruction is rejected" ;;
      *) assert_contains "$errors" 'assigns tracker state' "the tracker-write instruction is rejected" ;;
    esac
  done
done

test_case "a missing actor-local rule fails the ownership check"
damaged="$(newdir)/wave-gate.md"
awk '
  $0 == "## 1. E2E specialist agent" { target = 1 }
  target && !hit && /Never `git push`/ { sub(/Never `git push`/, ""); hit = 1 }
  { print }
' "$repo/src/skills/sift-drain/references/wave-gate.md" > "$damaged"
prompt="$(gate_prompt "$damaged" '## 1. E2E specialist agent')"
assert_not_contains "$prompt" 'Never `git push`' "the no-push rule is gone from the damaged prompt"
errors="$(contract_errors "$damaged")"
assert_contains "$errors" '## 1. E2E specialist agent: does not prohibit git push' \
  "the ownership check rejects a rule left outside the dispatched prompt"

# The required-ban greps match any case, so the exemption must too: a prompt
# whose ban reads `do not merge` is compliant, not a merge assignment. This
# control pins the recased phrase against a regression to exact-case stripping.
test_case "a recased ban phrase keeps its exemption"
damaged="$(newdir)/wave-gate.md"
sed 's/Do not merge\./do not merge./' \
  "$repo/src/skills/sift-drain/references/wave-gate.md" > "$damaged"
prompt="$(gate_prompt "$damaged" '## 4. Wave knowledge capture')"
assert_contains "$prompt" 'do not merge.' "the ban phrase is lowercased in the damaged copy"
assert_eq "" "$(contract_errors "$damaged")" \
  "a recased ban is still a ban, not a merge assignment"

test_case "an inflected merge instruction is rejected"
damaged="$(newdir)/wave-gate.md"
awk -v damage='Ensure the branch is merged into main before reporting.' '
  $0 == "## 1. E2E specialist agent" { section = 1 }
  section && !inserted && /^```$/ { print; print damage; inserted = 1; next }
  { print }
' "$repo/src/skills/sift-drain/references/wave-gate.md" > "$damaged"
assert_contains "$(gate_prompt "$damaged" '## 1. E2E specialist agent')" \
  'is merged into main' "the inflected instruction is inside the prompt"
assert_contains "$(contract_errors "$damaged")" \
  '## 1. E2E specialist agent: assigns a merge' "the inflected form is caught"

# The optional code reviewer, from this harness or another one, only reports.
# It commits nothing and may write only scratch files, so instead of the commit
# rules it carries its write limits and the evidence a run produces.
review_errors() {
  local prompt flattened
  prompt="$(gate_prompt "$1" '## Reviewer prompt')"
  [ -n "$prompt" ] || { printf 'reviewer: missing prompt\n'; return; }
  flattened="$(printf '%s\n' "$prompt" | tr '\n' ' ')"
  for rule in \
    'Verify every named path' \
    'Put the command and the output that shows the problem in `evidence`' \
    'Write only scratch files' \
    'a temporary directory outside every checkout' \
    'Never reinstall the shared dev environment' \
    'Do not edit or delete files tracked in git.' \
    'Do not commit.' \
    'Do not merge.' \
    'Never `git push`.' \
    'Never run `git checkout`, `git switch`, `git reset`, `git clean`, `git stash` or `git add`' \
    'Do not write tracker state.' \
    'Do not edit the sift-drain skill.' \
    'Never file, comment on, or patch an external tracker.' \
    'Do not write patches; describe the fix in one line.' \
    'A scratch script is evidence, not a fix.' \
    'type: dx' \
    'findings: <count>'
  do
    printf '%s\n' "$flattened" | grep -Fq "$rule" || printf 'reviewer: missing %s\n' "$rule"
  done
}

review="$repo/src/skills/sift-drain/references/code-review.md"

test_case "the code reviewer prompt limits writes to scratch files and leaves ownership to the orchestrator"
assert_eq "" "$(review_errors "$review")" "every reviewer rule remains inside the reviewer prompt"

test_case "a missing reviewer rule fails the reviewer check"
damaged="$(newdir)/code-review.md"
sed 's/Do not commit\. //' "$review" > "$damaged"
assert_not_contains "$(gate_prompt "$damaged" '## Reviewer prompt')" 'Do not commit.' \
  "the no-commit rule is gone from the damaged prompt"
assert_contains "$(review_errors "$damaged")" 'reviewer: missing Do not commit.' \
  "the reviewer check rejects the missing rule"

# Every reviewer is checked by comparing integration state before and after
# it runs. Execute the documented snapshot command on a real checkout.
# sh_block <file> <n> prints the nth ```sh block without its list indent.
sh_block() {
  awk -v want="$2" '
    /^[[:space:]]*```sh$/ { n++; inside = (n == want); next }
    inside && /^[[:space:]]*```$/ { exit }
    inside { sub(/^   /, ""); print }
  ' "$1"
}

snapshot() {
  (cd "$1" && SIFT_ROOT="$1" SCRIPTS_DIR="$repo/src/skills/sift-drain/scripts" STATE_BEFORE="$2" bash -c "$cmd")
}

test_case "the reviewer snapshot ignores the review worktree and catches outside writes"
cmd="$(sh_block "$review" 1)"
assert_contains "$cmd" 'review-state.sh" snapshot' "the documented snapshot invokes the real Git/tracker guard"
d="$(newdir)"
git -C "$d" init -q
printf 'code\n' > "$d/code.txt"
git -C "$d" add code.txt
git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm initial
git -C "$d" branch -M main
mkdir -p "$d/.ai/sift/open"
mkdir -p "$d/.ai/sift/config"
printf 'prefix: SFT\n' > "$d/.ai/sift/config/config.yaml"
printf 'live tracker\n' > "$d/.ai/sift/open/live.md"
printf '.ai/\n' > "$d/.git/info/exclude"
git -C "$d" worktree add -q -b sift-review-wave-1 "$TMPROOT/review" main
states="$(newdir)"
snapshot "$d" "$states/before"
assert_contains "$(cat "$states/before")" '@tracker' "the real helper produced a complete snapshot"
printf 'scratch\n' > "$TMPROOT/review/scratch.txt"
snapshot "$d" "$states/clean"
assert_eq 0 "$(cmp -s "$states/before" "$states/clean"; echo $?)" "writes inside the review worktree do not trip the check"
printf 'rewritten\n' > "$d/.ai/sift/open/live.md"
snapshot "$d" "$states/tracker"
assert_eq 1 "$(cmp -s "$states/before" "$states/tracker"; echo $?)" "an ignored tracker edit is caught"
printf 'live tracker\n' > "$d/.ai/sift/open/live.md"
printf 'changed\n' > "$d/code.txt"
snapshot "$d" "$states/code"
assert_eq 1 "$(cmp -s "$states/before" "$states/code"; echo $?)" "a tracked edit is caught"
printf 'code\n' > "$d/code.txt"
printf 'one\n' > "$d/notes.txt"
snapshot "$d" "$states/untracked-before"
printf 'two\n' > "$d/notes.txt"
snapshot "$d" "$states/untracked-after"
assert_eq 1 "$(cmp -s "$states/untracked-before" "$states/untracked-after"; echo $?)" "an edit to an existing untracked file is caught"
rm "$d/notes.txt"
git -C "$d" branch stray
snapshot "$d" "$states/ref"
assert_eq 1 "$(cmp -s "$states/before" "$states/ref"; echo $?)" "a new ref is caught"
git -C "$d" branch -q -D stray
snapshot "$d" "$states/restored"
assert_eq 0 "$(cmp -s "$states/before" "$states/restored"; echo $?)" "the snapshot is stable once state is restored"

# Step 6 sorts what the reviewer left in its worktree: untracked scratch files
# are counted, any other status line is a changed tracked file. Run the
# documented commands on the same checkout.
test_case "the review worktree check counts scratch files apart from tracked changes"
status_cmd="$(sh_block "$review" 3)"
remove_cmd="$(sh_block "$review" 4)"
assert_contains "$status_cmd" 'git -C "$REVIEW_WORKTREE" status --porcelain' "step 6 lists the review worktree"
assert_contains "$remove_cmd" 'git worktree remove --force' "step 6 removes a worktree that holds scratch files"
review_status() {
  (cd "$d" && REVIEW_WORKTREE="$wt" REVIEW_STATUS="$states/status" bash -c "$status_cmd")
}
snapshot "$d" "$states/before-review"
wt="$(newdir)/review"
git -C "$d" worktree add -q -b sift-review-wave-2 "$wt" main
assert_eq 0 "$(review_status)" "a clean worktree has no scratch files and no violation"
mkdir "$wt/scratch"
printf 'repro\n' > "$wt/scratch/repro.sh"
printf 'test\n' > "$wt/scratch/throwaway.test.sh"
assert_eq 2 "$(review_status)" "each scratch file counts, and scratch files are no violation"
printf 'edited\n' > "$wt/code.txt"
assert_eq "$(printf '2\n M code.txt')" "$(review_status)" "a tracked edit is listed apart from the scratch count"
(cd "$d" && REVIEW_WORKTREE="$wt" REVIEW_BRANCH=sift-review-wave-2 bash -c "$remove_cmd") >/dev/null
assert_no_dir "$wt" "the worktree is removed with its scratch files"
assert_eq "" "$(git -C "$d" branch --list sift-review-wave-2)" "the review branch is deleted"
snapshot "$d" "$states/after-review"
assert_eq 0 "$(cmp -s "$states/before-review" "$states/after-review"; echo $?)" "the integration checkout and tracker are as before"

test_case "review comparison permits only exact authorized publication and keeps historical tamper checks"
comparison="$(sh_block "$review" 2)"
assert_contains "$comparison" 'review-state.sh" compare' "comparison uses the narrow helper"
assert_contains "$comparison" 'ALLOW_EVENTS' "allowances come from coordinator receipts"
assert_contains "$(cat "$review")" 'outside the critical snapshot comparison window' "estimate writes cannot masquerade as reviewer events"
scripts="$repo/src/skills/sift-drain/scripts"
snapshot "$d" "$states/event-before"
receipt="$(SIFT_ROOT="$d" "$scripts/drain-log.sh" event run-start actor=coordinator)"
assert_file "$receipt" "the coordinator has an actual publication receipt"
compare_documented() (
  cd "$d" || exit
  export SIFT_ROOT="$d" SCRIPTS_DIR="$scripts"
  export STATE_BEFORE="$states/event-before" STATE_AFTER="$states/event-after"
  # The extracted normative block reads this Bash array through eval below.
  # shellcheck disable=SC2034
  ALLOW_EVENTS=("$@")
  # Execute the documented block with a real Bash array, never interpolate receipt data.
  eval "$comparison"
)
if compare_documented > "$states/compare.out" 2> "$states/compare.err"; then R_STATUS=0; else R_STATUS=$?; fi
assert_eq 1 "$R_STATUS" "new publication without authorization is rejected"
if compare_documented --allow-event "$receipt" > "$states/compare.out" 2> "$states/compare.err"; then R_STATUS=0; else R_STATUS=$?; fi
R_ERR="$(cat "$states/compare.err")"
assert_eq 0 "$R_STATUS" "the exact new receipt is allowed by the documented comparison"
snapshot "$d" "$states/event-before"
sed "s/actor: 'coordinator'/actor: 'worker'/" "$receipt" > "$receipt.tmp" && mv "$receipt.tmp" "$receipt"
if compare_documented --allow-event "$receipt" > "$states/compare.out" 2> "$states/compare.err"; then R_STATUS=0; else R_STATUS=$?; fi
R_ERR="$(cat "$states/compare.err")"
assert_eq 1 "$R_STATUS" "an allowance cannot authorize a historical record change"
assert_contains "$R_ERR" 'changed historical tracker file' "the reason preserves history protection"

test_case "integrated gate ownership replaces repeated broad runs without waiving final obligations"
gate="$repo/src/skills/sift-drain/references/wave-gate.md"
close="$(awk '$0 == "## 5. Closing the wave" {p=1} p' "$gate")"
assert_contains "$close" 'ALL required obligations' "close evaluates the complete final obligation set"
assert_contains "$close" 'validate-declared' "close checks actual declared inputs"
assert_contains "$close" 'missing/invalidated checks' "uncovered final obligations execute"
assert_contains "$close" 'exactly one owner' "shared broad checks have a single owner"
assert_contains "$(gate_prompt "$gate" '## 3. Root-cause fixes')" 'Batch independent root-cause repairs' "repairs batch before integrated execution"
assert_not_contains "$(gate_prompt "$gate" '## 3. Root-cause fixes')" 'then every full suite' "each repair no longer repeats broad gate checks"
assert_contains "$(gate_prompt "$gate" '## 2. Batch coverage agent')" 'Do not add a fresh coverage audit' "coverage consumes existing waived criteria"

summary
