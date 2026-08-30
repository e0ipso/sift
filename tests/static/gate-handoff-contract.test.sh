#!/usr/bin/env bash
# Static analysis: the actions sift skills take after gate exits 4 and 6.
#
# sift-gate.sh owns the state and exit-code mapping. sift-init owns the writes.
# Drain and prime consume both contracts, so a stale handoff can pause a repair
# that needs no user decision. This check reads the action lines from all four
# documents and rejects a disagreement. The mutation cases prove each consumer
# and each exit can make the comparison fail.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

SELF="tests/static/$(basename "$0")"
INIT="src/skills/sift-init/SKILL.md"
GATE="src/skills/sift-init/scripts/sift-gate.sh"
CONSUMERS="src/skills/sift-drain/SKILL.md
src/skills/sift-prime/SKILL.md"
EXPECTED="4 approval
6 repair"

# handoff_map <file> — normalize that file's exit 4 and 6 action lines to
# "<exit> <action>". The action word comes from the instruction itself. Checking
# for repair first keeps "repair without asking" on the repair side.
handoff_map() {
  awk '
    function action(code, line, lower) {
      lower = tolower(line)
      if (index(lower, "repair")) print code " repair"
      else if (index(lower, "ask")) print code " approval"
    }
    /^- \*\*4 \(`/ { action("4", $0); next }
    /^- \*\*6 \(`/ { action("6", $0); next }
    /^\| 4 \|/       { action("4", $0); next }
    /^\| 6 \|/       { action("6", $0); next }
    /^#   4  /        { action("4", $0); next }
    /^#   6  /        { action("6", $0); next }
  ' "$1" | LC_ALL=C sort -u
}

test_case "the init skill and gate script declare one shared handoff contract"
for document in "$INIT" "$GATE"; do
  assert_file "$REPO_ROOT/$document" "$document exists"
  assert_eq "$EXPECTED" "$(handoff_map "$REPO_ROOT/$document")" \
    "$document maps exit 4 to approval and exit 6 to repair"
done

test_case "drain and prime match the init and gate handoff contract"
canonical="$(handoff_map "$REPO_ROOT/$INIT")"
gate_map="$(handoff_map "$REPO_ROOT/$GATE")"
assert_eq "$canonical" "$gate_map" "the gate script matches the init skill"
for document in $CONSUMERS; do
  assert_file "$REPO_ROOT/$document" "$document exists"
  assert_eq "$canonical" "$(handoff_map "$REPO_ROOT/$document")" \
    "$document matches the canonical handoff"
done

test_case "every handoff document names the check that reads it"
for document in "$INIT" "$GATE" $CONSUMERS; do
  if grep -Fq -e "$SELF" "$REPO_ROOT/$document"; then
    t_ok "$document names $SELF"
  else
    t_fail "$document names $SELF" "the document never names its handoff check"
  fi
done

test_case "either consumer drifting on either exit fails the comparison"
for document in $CONSUMERS; do
  for code in 4 6; do
    work="$(newdir)"
    victim="$work/SKILL.md"
    awk -v code="$code" '
      code == "4" && /^- \*\*4 \(`/ {
        sub(/and ask$/, "and repair without asking")
      }
      code == "6" && /^- \*\*6 \(`/ {
        sub(/repair without asking/, "ask first")
      }
      { print }
    ' "$REPO_ROOT/$document" > "$victim"

    if [ "$code" = 4 ]; then
      changed_line="$(awk '/^- \*\*4 \(`/ { print; exit }' "$victim")"
      assert_contains "$changed_line" "repair without asking" \
        "$document exit 4 was changed to repair in the copy"
    else
      changed_line="$(awk '/^- \*\*6 \(`/ { print; exit }' "$victim")"
      assert_contains "$changed_line" "ask first" \
        "$document exit 6 was changed to approval in the copy"
    fi
    assert_ne "$canonical" "$(handoff_map "$victim")" \
      "$document exit $code drift is rejected"
  done
done

summary
