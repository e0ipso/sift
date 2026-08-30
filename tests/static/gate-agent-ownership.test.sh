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
    '## 3. Fix agents — one per root cause' \
    '## 4. Knowledge capture — once, for the whole wave'
  do
    prompt="$(gate_prompt "$file" "$heading")"
    [ -n "$prompt" ] || { printf '%s: missing prompt\n' "$heading"; continue; }
    flattened="$(printf '%s\n' "$prompt" | tr '\n' ' ')"
    printf '%s\n' "$flattened" | grep -Fq 'Verify every named path' ||
      printf '%s: does not require live path verification\n' "$heading"
    printf '%s\n' "$flattened" | grep -Fq 'Branch off local' ||
      printf '%s: does not require a local branch\n' "$heading"
    printf '%s\n' "$prompt" | grep -Eq 'commit your scoped changes|commit the scoped changes' ||
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
      '## 4. Knowledge capture — once, for the whole wave') ;;
      *) printf '%s\n' "$flattened" | grep -Fq 'Do not capture durable knowledge' ||
           printf '%s: does not defer durable knowledge capture\n' "$heading" ;;
    esac
    without_bans="$(printf '%s\n' "$flattened" | sed \
      -e 's/Do not merge//g' \
      -e 's/Do not write tracker state//g')"
    if printf '%s\n' "$without_bans" | grep -Eiq '(^|[^[:alnum:]_])merge([^[:alnum:]_]|$)'; then
      printf '%s: assigns a merge to the gate agent\n' "$heading"
    fi
    if printf '%s\n' "$without_bans" | grep -Eq 'ROADMAP\.md|file a sift ticket|tickets filed:|[Ww]rite tracker state'; then
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
  '## 3. Fix agents — one per root cause' \
  '## 4. Knowledge capture — once, for the whole wave'
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
  target && !hit && /NEVER `git push`/ { sub(/NEVER `git push`/, ""); hit = 1 }
  { print }
' "$repo/src/skills/sift-drain/references/wave-gate.md" > "$damaged"
prompt="$(gate_prompt "$damaged" '## 1. E2E specialist agent')"
assert_not_contains "$prompt" 'NEVER `git push`' "the no-push rule is gone from the damaged prompt"
errors="$(contract_errors "$damaged")"
assert_contains "$errors" '## 1. E2E specialist agent: does not prohibit git push' \
  "the ownership check rejects a rule left outside the dispatched prompt"

summary
