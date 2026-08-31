#!/usr/bin/env bash
# Static analysis: the full workflow delegates three stages without a pause.
#
# The tagged records are the handoff contract. Plan creation may clarify before
# allocation. Successful stages pass one numeric plan ID forward without
# approval. Any failed stage stops the workflow. Damage copies to prove each pin
# can fail.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

SKILL="$REPO_ROOT/.agents/skills/st-full-workflow/SKILL.md"
STAGE_TAG='@FULL-WORKFLOW-STAGE:'
FLOW_TAG='@FULL-WORKFLOW:'

CREATE_STAGE='@FULL-WORKFLOW-STAGE: .agents/skills/st-create-plan/ name: st-create-plan'
GENERATE_STAGE='@FULL-WORKFLOW-STAGE: .agents/skills/st-generate-tasks/ name: st-generate-tasks'
EXECUTE_STAGE='@FULL-WORKFLOW-STAGE: .agents/skills/st-execute-blueprint/ name: st-execute-blueprint'

CLARIFY='@FULL-WORKFLOW: clarify st-create-plan before-plan-id'
PLAN_TO_TASKS='@FULL-WORKFLOW: handoff st-create-plan st-generate-tasks numeric-plan-id no-approval'
TASKS_TO_EXECUTION='@FULL-WORKFLOW: handoff st-generate-tasks st-execute-blueprint same-numeric-plan-id no-approval'
STOP='@FULL-WORKFLOW: stop blocked-or-failed report-no-fallback'

records_with() {
  awk -v tag="$2" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, tag) == 1) print line
    }
  ' "$1"
}

count_exact() {
  awk -v want="$2" '$0 == want { n++ } END { print n + 0 }' "$1"
}

front_matter_of() {
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside { print }
  ' "$1"
}

stage_pin_errors() {
  local skill="$1" line rest target construct stage_file
  records_with "$skill" "$STAGE_TAG" | while IFS= read -r line; do
    rest="${line#"$STAGE_TAG" }"
    target="${rest%% *}"
    construct="${rest#"$target" }"
    stage_file="$REPO_ROOT/${target%/}/SKILL.md"
    if [ ! -f "$stage_file" ]; then
      printf '%s\n' "$target has no SKILL.md"
    elif ! front_matter_of "$stage_file" | grep -Fxq -e "$construct"; then
      printf '%s\n' "$target does not expose $construct"
    fi
  done
}

workflow_errors() {
  local skill="$1" actual expected

  [ "$(count_exact "$skill" "$CREATE_STAGE")" -eq 1 ] \
    || printf '%s\n' 'plan-creation stage pin missing or duplicated'
  [ "$(count_exact "$skill" "$GENERATE_STAGE")" -eq 1 ] \
    || printf '%s\n' 'task-generation stage pin missing or duplicated'
  [ "$(count_exact "$skill" "$EXECUTE_STAGE")" -eq 1 ] \
    || printf '%s\n' 'blueprint-execution stage pin missing or duplicated'

  [ "$(count_exact "$skill" "$CLARIFY")" -eq 1 ] \
    || printf '%s\n' 'pre-allocation clarification pin missing or duplicated'
  [ "$(count_exact "$skill" "$PLAN_TO_TASKS")" -eq 1 ] \
    || printf '%s\n' 'plan-to-tasks no-approval handoff pin missing or duplicated'
  [ "$(count_exact "$skill" "$TASKS_TO_EXECUTION")" -eq 1 ] \
    || printf '%s\n' 'tasks-to-execution same-ID handoff pin missing or duplicated'
  [ "$(count_exact "$skill" "$STOP")" -eq 1 ] \
    || printf '%s\n' 'stop-on-failure pin missing or duplicated'

  expected="$(printf '%s\n%s\n%s' "$CREATE_STAGE" "$GENERATE_STAGE" "$EXECUTE_STAGE")"
  actual="$(records_with "$skill" "$STAGE_TAG")"
  [ "$actual" = "$expected" ] || printf '%s\n' 'stage pins are not the exact ordered trio'

  expected="$(printf '%s\n%s\n%s\n%s' \
    "$CLARIFY" "$PLAN_TO_TASKS" "$TASKS_TO_EXECUTION" "$STOP")"
  actual="$(records_with "$skill" "$FLOW_TAG")"
  [ "$actual" = "$expected" ] || printf '%s\n' 'workflow pins are not in transition order'
}

copy_without() {
  local source="$1" destination="$2" line="$3"
  awk -v want="$line" '$0 != want { print }' "$source" > "$destination"
}

test_case "the orchestrator pins the authoritative stage trio and transition graph"
assert_file "$SKILL" "the full-workflow skill exists"
assert_eq "" "$(workflow_errors "$SKILL")" \
  "every stage and workflow pin appears once and in order"
assert_eq "" "$(stage_pin_errors "$SKILL")" \
  "every stage pin resolves to the named skill front matter"

test_case "the orchestrator carries no local stage procedure"
body="$(cat "$SKILL")"
assert_not_contains "$body" 'scripts/' "the orchestrator invokes no copied stage helper"
assert_not_contains "$body" '#### ' "the orchestrator embeds no stage sub-procedure"
assert_not_contains "$body" 'complexity_score' "task complexity rules stay in task generation"
assert_not_contains "$body" 'PRE_PHASE.md' "phase mechanics stay in blueprint execution"

test_case "removing one stage handoff fails the stage graph"
work="$(newdir)"
damaged="$work/SKILL.md"
copy_without "$SKILL" "$damaged" "$GENERATE_STAGE"
assert_not_contains "$(records_with "$damaged" "$STAGE_TAG")" "$GENERATE_STAGE" \
  "the task-generation stage pin is absent from the damaged copy"
assert_contains "$(workflow_errors "$damaged")" \
  'task-generation stage pin missing or duplicated' \
  "the graph check names the missing stage"

test_case "removing pre-allocation clarification fails its pin"
work="$(newdir)"
damaged="$work/SKILL.md"
copy_without "$SKILL" "$damaged" "$CLARIFY"
assert_not_contains "$(records_with "$damaged" "$FLOW_TAG")" "$CLARIFY" \
  "the clarification edge is absent from the damaged copy"
assert_contains "$(workflow_errors "$damaged")" \
  'pre-allocation clarification pin missing or duplicated' \
  "the graph check names the missing clarification edge"

test_case "turning the success path into an approval pause fails both handoffs"
work="$(newdir)"
damaged="$work/SKILL.md"
awk -v tag="$FLOW_TAG" '
  index($0, tag) == 1 { sub(/no-approval/, "approval-required") }
  { print }
' "$SKILL" > "$damaged"
assert_not_contains "$(records_with "$damaged" "$FLOW_TAG")" 'no-approval' \
  "both success handoffs now require approval in the damaged copy"
errors="$(workflow_errors "$damaged")"
assert_contains "$errors" 'plan-to-tasks no-approval handoff pin missing or duplicated' \
  "the graph check names the first approval pause"
assert_contains "$errors" 'tasks-to-execution same-ID handoff pin missing or duplicated' \
  "the graph check names the second approval pause"

test_case "changing the plan ID between stages fails the handoff"
work="$(newdir)"
damaged="$work/SKILL.md"
awk -v want="$TASKS_TO_EXECUTION" '
  $0 == want { sub(/same-numeric-plan-id/, "new-numeric-plan-id") }
  { print }
' "$SKILL" > "$damaged"
assert_not_contains "$(records_with "$damaged" "$FLOW_TAG")" 'same-numeric-plan-id' \
  "the immutable ID edge is absent from the damaged copy"
assert_contains "$(workflow_errors "$damaged")" \
  'tasks-to-execution same-ID handoff pin missing or duplicated' \
  "the graph check names the changed plan ID"

test_case "removing stop-on-failure fails its pin"
work="$(newdir)"
damaged="$work/SKILL.md"
copy_without "$SKILL" "$damaged" "$STOP"
assert_not_contains "$(records_with "$damaged" "$FLOW_TAG")" "$STOP" \
  "the failure edge is absent from the damaged copy"
assert_contains "$(workflow_errors "$damaged")" \
  'stop-on-failure pin missing or duplicated' \
  "the graph check names the missing stop edge"

summary
