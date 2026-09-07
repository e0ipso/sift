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

summary
