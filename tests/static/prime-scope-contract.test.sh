#!/usr/bin/env bash
# Static analysis: sift-prime's fenced and unfenced inspection contract.
#
# The analysis reference, the skill's restatement and its derived knowledge all
# tell an agent where a fenced sweep may read and what that sweep may report. If
# one of them requires findings from outside a fence that another instruction
# forbids the agent to inspect, the agent can only invent those findings or
# violate the fence. Each document therefore carries the same pair of
# @PRIME-SCOPE markers, and this check also rejects the contradictory closing-line
# language that caused SFT-0095.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

MARKER='@PRIME-SCOPE:'
FENCED='fenced reads-and-reports-inside'
UNFENCED='unfenced full-breadth'
EXPECTED="$FENCED
$UNFENCED"
SELF="tests/static/$(basename "$0")"
DOCS="src/skills/sift-prime/references/analysis.md
src/skills/sift-prime/SKILL.md
.ai/kenkeep/nodes/sift-prime/practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md"

# markers_of <document> — one contract value per marker, in document order.
markers_of() {
  awk -v tag="$MARKER" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (index(line, tag) != 1) next
      line = substr(line, length(tag) + 1)
      sub(/^[[:space:]]+/, "", line)
      if (line != "") print line
    }
  ' "$1"
}

# contradictions_in <document> — prohibited reporting claims, but only when
# the same document declares that fenced reads and reports share one boundary.
# Empty output means the document does not require knowledge it forbids itself
# to inspect.
contradictions_in() {
  local document="$1"
  markers_of "$document" | grep -Fxq -e "$FENCED" || return 0
  awk '
    {
      line = tolower($0)
      if (index(line, "findings outside the fence") ||
          index(line, "out-of-fence findings") ||
          index(line, "out-of-fence closing line"))
        printf "%d:%s\n", NR, $0
    }
  ' "$document"
}

test_case "every scope-contract document declares the same boundary"
for document in $DOCS; do
  assert_file "$REPO_ROOT/$document" "$document exists"
  assert_eq "$EXPECTED" "$(markers_of "$REPO_ROOT/$document")" \
    "$document carries the fenced and unfenced contract"
done

test_case "every scope-contract document names the check that reads it"
for document in $DOCS; do
  if grep -Fq -e "$SELF" "$REPO_ROOT/$document"; then
    t_ok "$document names $SELF"
  else
    t_fail "$document names $SELF" "the document never names its contract check"
  fi
done

test_case "a fenced read boundary never requires out-of-fence findings"
for document in $DOCS; do
  assert_eq "" "$(contradictions_in "$REPO_ROOT/$document")" \
    "$document reports only what its fenced sweep inspected"
done

test_case "a contradictory closing-line requirement fails the check"
work="$(newdir)"
victim="$work/analysis.md"
cp "$REPO_ROOT/src/skills/sift-prime/references/analysis.md" "$victim"
assert_eq "" "$(contradictions_in "$victim")" "the untouched copy is consistent"
printf '\nFindings outside the fence become one closing line.\n' >> "$victim"
assert_contains "$(cat "$victim")" "Findings outside the fence become one closing line." \
  "the conflicting requirement was added to the copy"
assert_ne "" "$(contradictions_in "$victim")" \
  "the identical comparison rejects the conflicting contract"

summary
