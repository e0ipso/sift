#!/usr/bin/env bash
# Static analysis: ordered agent-prompt contracts.
#
# A worker cannot report a follow-up ID before the ticket exists. Keep the filing
# step before the single final report, and keep the report's `tickets filed` field
# explicit so every new ID reaches the orchestrator.
#
# The sift-prime drafting prompt has six numbered steps. Its preamble points the
# XSD pins at step 3 and the body-heading pins at step 4. Its two rule-9 markers
# belong to the roadmap-reading instruction in step 2 and the write-scope
# instruction in step 5, not to one repeated site.
#
# The Claude and Cursor plan-creator prompts are two platform entry points for one
# contract. Keep their bytes equal and their seven phases in the declared order.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

PROMPT="$REPO_ROOT/src/skills/sift-drain/references/ticket-agent-prompt.md"
DRAFTING_PROMPT="$REPO_ROOT/src/skills/sift-prime/references/drafting-agent-prompt.md"
CLAUDE_PLAN="$REPO_ROOT/.claude/agents/plan-creator.md"
CURSOR_PLAN="$REPO_ROOT/.cursor/agents/plan-creator.md"
FOLLOW_HEADING='Step 5: File warranted follow-ups'
REPORT_HEADING='Step 6: Return one final report'
ID_REQUIREMENT='final `tickets filed` field.'
FIELD='tickets filed: <IDs> | none'
WORKER_SCHEMA='status
branch
commits
resolution
summary
verification
sitting verification
live check
test edits
deferred to the wave gate
tickets filed
tamper'
PLAN_PHASES='## 1. Load the inputs
## 2. Control scope
## 3. Allocate the plan ID
## 4. Produce the plan document
## 5. Enforce the content boundary
## 6. Write and validate the file
## 7. Report the result'
DRAFTING_STEPS='1
2
3
4
5
6'
DRAFTING_REFERENCES='STEP 3
STEP 4
STEP 3
STEP 4'
DRAFTING_RULE9='@RULE: README.md 9 in sync — in the same change'
DRAFTING_RULE9_STEPS='2
5'

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

drafting_step_numbers() {
  awk '
    $0 == "## Template" { seek_fence = 1; next }
    seek_fence && $0 == "```" { in_template = 1; seek_fence = 0; next }
    in_template && $0 == "```" { exit }
    in_template && /^[0-9][0-9]*\.[[:space:]]/ {
      step = $0
      sub(/\..*$/, "", step)
      print step
    }
  ' "$1"
}

drafting_preamble_references() {
  awk '
    $0 == "## Template" { exit }
    {
      line = $0
      while (match(line, /STEP[[:space:]][0-9][0-9]*/)) {
        print substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

drafting_rule9_steps() {
  awk -v marker="$DRAFTING_RULE9" '
    $0 == "## Template" { seek_fence = 1; next }
    seek_fence && $0 == "```" { in_template = 1; seek_fence = 0; next }
    in_template && $0 == "```" { exit }
    in_template && /^[0-9][0-9]*\.[[:space:]]/ {
      step = $0
      sub(/\..*$/, "", step)
    }
    in_template {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == marker) print step
    }
  ' "$1"
}

adjacent_drafting_rule9_markers() {
  awk -v marker="$DRAFTING_RULE9" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == marker && previous == marker)
        printf "%d:%d\n", NR - 1, NR
      previous = line
    }
  ' "$1"
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

worker_report_fields() {
  awk -v report="$REPORT_HEADING" '
    $0 == report { section = 1; next }
    section && /^```$/ { exit }
    section && /^  [[:lower:]][[:lower:] ]*:/ {
      field = $0
      sub(/^  /, "", field)
      sub(/:.*/, "", field)
      print field
    }
  ' "$1"
}

worker_schema_owners() {
  # `sitting verification` is unique to the worker report. A second exact
  # schema would have to copy it, while the gate agents have their own reports.
  grep -l '^  sitting verification:' \
    "$REPO_ROOT/src/skills/sift-drain/SKILL.md" \
    "$REPO_ROOT/src/skills/sift-drain/references/"*.md \
    | while IFS= read -r f; do printf '%s\n' "${f#"$REPO_ROOT/"}"; done
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

test_case "the canonical prompt owns the exact ordered worker report schema"
assert_eq "$WORKER_SCHEMA" "$(worker_report_fields "$PROMPT")" \
  "the final report keeps every top-level field in contract order"
assert_eq 'src/skills/sift-drain/references/ticket-agent-prompt.md' \
  "$(worker_schema_owners)" \
  "the worker-only schema is not copied into orchestration or gate documents"

test_case "removing a worker report field fails the schema check"
work="$(newdir)"
damaged="$work/ticket-agent-prompt.md"
awk '!/^  resolution: <TICKET-ID>:/' "$PROMPT" > "$damaged"
assert_not_contains "$(worker_report_fields "$damaged")" 'resolution' \
  "the resolution field is gone from the damaged schema"
assert_ne "$WORKER_SCHEMA" "$(worker_report_fields "$damaged")" \
  "the schema comparison rejects the missing field"

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

test_case "the drafting prompt keeps its six-step reference contract"
assert_file "$DRAFTING_PROMPT" "the canonical drafting prompt exists"
assert_eq "$DRAFTING_STEPS" "$(drafting_step_numbers "$DRAFTING_PROMPT")" \
  "the drafting template exposes exactly six ordered steps"
assert_eq "$DRAFTING_REFERENCES" "$(drafting_preamble_references "$DRAFTING_PROMPT")" \
  "the XSD and body-heading pins name their owning steps"

test_case "a stale drafting step reference fails the reference check"
work="$(newdir)"
damaged="$work/drafting-agent-prompt.md"
awk '
  !changed && index($0, "STEP 3 names the XSD") {
    sub(/STEP 3/, "STEP 2")
    changed = 1
  }
  { print }
' "$DRAFTING_PROMPT" > "$damaged"
assert_contains "$(cat "$damaged")" "STEP 2 names the XSD" \
  "the copy points the XSD claim at its former step"
assert_ne "$(drafting_preamble_references "$DRAFTING_PROMPT")" \
  "$(drafting_preamble_references "$damaged")" \
  "the stale-reference mutation changed the live contract"
assert_ne "$DRAFTING_REFERENCES" "$(drafting_preamble_references "$damaged")" \
  "the reference comparison rejects the stale step number"

test_case "the drafting rule-9 markers pin two owning steps"
assert_eq "$DRAFTING_RULE9_STEPS" "$(drafting_rule9_steps "$DRAFTING_PROMPT")" \
  "the roadmap-read and write-scope statements each carry one rule-9 marker"
assert_eq '' "$(adjacent_drafting_rule9_markers "$DRAFTING_PROMPT")" \
  "the two rule-9 markers are not adjacent"

test_case "adjacent drafting rule-9 markers fail the placement check"
work="$(newdir)"
damaged="$work/drafting-agent-prompt.md"
awk -v marker="$DRAFTING_RULE9" '
  $0 == marker && !moved { moved = 1; next }
  $0 == marker && moved { print; print; moved = 0; next }
  { print }
' "$DRAFTING_PROMPT" > "$damaged"
assert_eq '5
5' "$(drafting_rule9_steps "$damaged")" \
  "the copy co-locates both markers at the write-scope statement"
assert_ne "$(drafting_rule9_steps "$DRAFTING_PROMPT")" \
  "$(drafting_rule9_steps "$damaged")" \
  "the adjacent-marker mutation changed the live placement"
assert_ne '' "$(adjacent_drafting_rule9_markers "$damaged")" \
  "the placement check rejects adjacent rule-9 markers"

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
