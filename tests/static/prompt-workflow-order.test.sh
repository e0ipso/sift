#!/usr/bin/env bash
# Static analysis: ordered agent-prompt contracts.
#
# A worker cannot report a follow-up ID before the ticket exists. Keep the filing
# step before the single final report, and keep the report's `tickets filed` field
# explicit so every new ID reaches the orchestrator.
#
# The Claude and Cursor plan-creator prompts are two platform entry points for one
# contract. Keep their bytes equal and their seven phases in the declared order.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

PROMPT="$REPO_ROOT/src/skills/sift-drain/references/ticket-agent-prompt.md"
CLAUDE_PLAN="$REPO_ROOT/.claude/agents/plan-creator.md"
CURSOR_PLAN="$REPO_ROOT/.cursor/agents/plan-creator.md"
FOLLOW_HEADING='Step 5: File warranted follow-ups'
REPORT_HEADING='Step 6: Return one final report'
ID_REQUIREMENT='final `tickets filed` field.'
FIELD='tickets filed: <IDs> | none'
PLAN_PHASES='## 1. Load the inputs
## 2. Control scope
## 3. Allocate the plan ID
## 4. Produce the plan document
## 5. Enforce the content boundary
## 6. Write and validate the file
## 7. Report the result'

count_exact() {
  awk -v want="$2" '$0 == want { n++ } END { print n + 0 }' "$1"
}

line_exact() {
  awk -v want="$2" '$0 == want { print NR; exit }' "$1"
}

line_containing() {
  awk -v want="$2" 'index($0, want) { print NR; exit }' "$1"
}

plan_phases() {
  awk '/^## [0-9]+\. / { print }' "$1"
}

ordering_error() {
  local prompt="$1" follow report
  follow="$(line_exact "$prompt" "$FOLLOW_HEADING")"
  report="$(line_exact "$prompt" "$REPORT_HEADING")"
  [ -n "$follow" ] || { printf '%s\n' 'follow-up heading missing'; return; }
  [ -n "$report" ] || { printf '%s\n' 'final report heading missing'; return; }
  [ "$follow" -lt "$report" ] || printf '%s\n' 'follow-up filing is not before the final report'
}

report_error() {
  local prompt="$1" report requirement field
  report="$(line_exact "$prompt" "$REPORT_HEADING")"
  requirement="$(line_containing "$prompt" "$ID_REQUIREMENT")"
  field="$(line_containing "$prompt" "$FIELD")"
  [ -n "$report" ] || { printf '%s\n' 'final report heading missing'; return; }
  [ -n "$requirement" ] || { printf '%s\n' 'self-filed ID requirement missing'; return; }
  [ -n "$field" ] || { printf '%s\n' 'tickets filed field missing'; return; }
  [ "$report" -lt "$requirement" ] && [ "$requirement" -lt "$field" ] \
    || printf '%s\n' 'self-filed ID requirement and field are not in the final report'
}

test_case "the workflow has one follow-up step and one final report"
assert_file "$PROMPT" "the canonical ticket-agent prompt exists"
assert_eq 1 "$(count_exact "$PROMPT" "$FOLLOW_HEADING")" "the follow-up heading appears once"
assert_eq 1 "$(count_exact "$PROMPT" "$REPORT_HEADING")" "the final report heading appears once"

test_case "follow-up filing precedes the final report"
assert_eq "" "$(ordering_error "$PROMPT")" "the final report runs after follow-up filing"

test_case "the final report surfaces every self-filed ticket"
assert_eq "" "$(report_error "$PROMPT")" \
  "the self-filed ID requirement and tickets filed field belong to the final report"

test_case "moving follow-up filing after the report fails the order check"
work="$(newdir)"
damaged="$work/ticket-agent-prompt.md"
awk -v follow="$FOLLOW_HEADING" -v report="$REPORT_HEADING" '
  $0 == follow { print report; next }
  $0 == report { print follow; next }
  { print }
' "$PROMPT" > "$damaged"
assert_eq "$REPORT_HEADING" "$(sed -n "$(line_exact "$PROMPT" "$FOLLOW_HEADING")p" "$damaged")" \
  "the copy now reports before filing follow-ups"
assert_eq "follow-up filing is not before the final report" "$(ordering_error "$damaged")" \
  "the order check names the regression"

test_case "removing tickets filed from the report fails the report check"
work="$(newdir)"
damaged="$work/ticket-agent-prompt.md"
awk -v field="$FIELD" '!index($0, field)' "$PROMPT" > "$damaged"
assert_not_contains "$(cat "$damaged")" "$FIELD" "the report field is gone from the copy"
assert_eq "tickets filed field missing" "$(report_error "$damaged")" \
  "the report check names the missing field"

test_case "the plan-creator platforms carry one byte-identical contract"
assert_file "$CLAUDE_PLAN" "the Claude plan-creator prompt exists"
assert_file "$CURSOR_PLAN" "the Cursor plan-creator prompt exists"
assert_same "$CLAUDE_PLAN" "$CURSOR_PLAN" \
  "both platforms receive the same contract byte for byte"

test_case "the plan-creator contract keeps its seven phases in order"
assert_eq "$PLAN_PHASES" "$(plan_phases "$CLAUDE_PLAN")" \
  "the shared contract exposes the exact ordered phase sequence"

test_case "moving a plan-creator phase fails the order check"
work="$(newdir)"
damaged="$work/plan-creator.md"
awk '
  $0 == "## 2. Control scope" { print "## 3. Allocate the plan ID"; next }
  $0 == "## 3. Allocate the plan ID" { print "## 2. Control scope"; next }
  { print }
' "$CLAUDE_PLAN" > "$damaged"
assert_ne "$PLAN_PHASES" "$(plan_phases "$damaged")" \
  "the phase-order comparison rejects the swapped headings"

summary
