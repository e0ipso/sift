#!/usr/bin/env bash
# Gate agents return commits and defect reports. The drain orchestrator alone
# merges and writes tracker state (SFT-0103).

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
    printf '%s\n' "$prompt" | grep -Eq 'commit your scoped changes|commit the scoped changes' ||
      printf '%s: does not require a commit\n' "$heading"
    printf '%s\n' "$prompt" | grep -Fq 'commit: <hash>' ||
      printf '%s: does not report the commit\n' "$heading"
    flattened="$(printf '%s\n' "$prompt" | tr '\n' ' ')"
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

test_case "all four gate templates commit and report under orchestrator ownership"
errors="$(contract_errors "$repo/src/skills/sift-drain/references/wave-gate.md")"
assert_eq "" "$errors" "the live gate prompts contain no merge or tracker-write instruction"

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

summary
