#!/usr/bin/env bash
# Static analysis: ordered agent-prompt contracts.
#
# A worker cannot report a follow-up ID before the ticket exists. Keep the filing
# step before the single final report, and keep the report's `tickets filed` field
# explicit so every new ID reaches the orchestrator.
#
# The sift-prime drafting prompt has six numbered steps. Its preamble points the
# XSD pins at step 3 and the body-heading pins at step 4. The wave the orchestrator
# negotiated reaches the agent as an assigned value in step 1 and is written into
# the ticket's front matter in step 4 — the two sites that make the ticket file the
# only place wave membership lives.
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
DRAFTING_STEP_CONTRACT='1 assigned-values
2 read-convention
3 read-schema
4 write-ticket
5 check-write-scope
6 return-report'
DRAFTING_REPORT_SCHEMA='status: written | blocked
ticket: <ID>
file: <absolute path>
type: <type>   priority: <priority>   effort: <effort>
evidence: <every citation rendered into ## Evidence>
judgment calls: <decisions you made yourself> | none'
DRAFTING_EVIDENCE_STEPS='1
4
4'
DRAFTING_WAVE_STEPS='1
4'

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

drafting_template() {
  awk '
    $0 == "## Template" { seek_fence = 1; next }
    seek_fence && $0 == "```" { in_template = 1; seek_fence = 0; next }
    in_template && $0 == "```" { exit }
    in_template { print }
  ' "$1"
}

drafting_step_contract() {
  drafting_template "$1" | awk '
    /^[0-9][0-9]*\.[[:space:]]/ {
      step = $0
      sub(/\..*$/, "", step)
    }
    index($0, "Use these assigned values exactly.") {
      print step " assigned-values"
    }
    index($0, "Read {{PROJECT_ROOT}}/.ai/sift/README.md in full.") {
      print step " read-convention"
    }
    index($0, "Read {{SCHEMA_PATH}}.") {
      print step " read-schema"
    }
    index($0, "Create the directory for {{TICKET_PATH}} and write the finished ticket") {
      print step " write-ticket"
    }
    index($0, "Check the write scope.") {
      print step " check-write-scope"
    }
    index($0, "Return exactly these fields and no other text.") {
      print step " return-report"
    }
  '
}

placeholders() {
  awk '
    {
      line = $0
      while (match(line, /\{\{[^{}][^{}]*\}\}/)) {
        print substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' | LC_ALL=C sort -u
}

drafting_table_placeholders() {
  awk '
    $0 == "| Placeholder | Source |" { in_table = 1 }
    in_table && $0 == "" { exit }
    in_table { print }
  ' "$1" | placeholders
}

drafting_template_placeholders() {
  drafting_template "$1" | placeholders
}

drafting_placeholder_steps() {
  drafting_template "$1" | awk -v placeholder="$2" '
    /^[0-9][0-9]*\.[[:space:]]/ {
      step = $0
      sub(/\..*$/, "", step)
    }
    {
      line = $0
      while (index(line, placeholder)) {
        print step
        line = substr(line, index(line, placeholder) + length(placeholder))
      }
    }
  '
}

drafting_report_schema() {
  drafting_template "$1" | awk '
    /^6\.[[:space:]]/ { in_report = 1; next }
    in_report {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^[[:lower:]][[:lower:][:space:]]*:/) print line
    }
  '
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

WAVE_PLACEHOLDER='{{WAVE}}'

# worker_table_placeholders <prompt> — the placeholders the sitting's own source
# table declares. The prompt carries later tables for the resume and redispatch
# templates; this reads the first, which is the sitting's.
worker_table_placeholders() {
  awk '
    $0 == "| Placeholder | Source |" { in_table = 1 }
    in_table && $0 == "" { exit }
    in_table { print }
  ' "$1" | placeholders
}

# worker_wave_sites <prompt> — the step heading above every {{WAVE}} use inside
# the template, one line per use. The declaration in the source table sits above
# the first step and is deliberately not one of them.
worker_wave_sites() {
  awk -v want="$WAVE_PLACEHOLDER" '
    /^Step [0-9][0-9]*: / { step = $0; sub(/:.*$/, "", step) }
    step != "" && index($0, want) { print step }
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

test_case "the worker prompt carries the sitting's wave into the ticket it files"
# Wave membership is a key in the ticket file, so a follow-up written without one
# is in no load and is dispatched by nobody. The placeholder is how the
# orchestrator's wave reaches the worker, and the filing step is the only place
# the worker has a ticket to put it in — a use anywhere else is a number with
# nothing to do, and no use at all is a ticket filed adrift.
assert_contains "$(worker_table_placeholders "$PROMPT")" "$WAVE_PLACEHOLDER" \
  "the sitting's wave is a declared input, not a number the agent invents"
assert_eq 'Step 5' "$(worker_wave_sites "$PROMPT")" \
  "and the template uses it at exactly one site: the step that files follow-ups"

test_case "a wave used outside the filing step fails the placement check"
work="$(newdir)"
damaged="$work/ticket-agent-prompt.md"
awk -v want='Step 3: Implement and commit each ticket' '
  $0 == want { print; print "Record wave {{WAVE}} in the commit message."; next }
  { print }
' "$PROMPT" > "$damaged"
assert_contains "$(worker_wave_sites "$damaged")" 'Step 3' \
  "the copy uses the wave where no ticket is being written"
assert_ne 'Step 5' "$(worker_wave_sites "$damaged")" \
  "the placement check rejects it"

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

test_case "the drafting steps each own one process requirement"
assert_eq "$DRAFTING_STEP_CONTRACT" "$(drafting_step_contract "$DRAFTING_PROMPT")" \
  "the six sole imperatives remain in their declared order"

test_case "moving drafting requirements between steps fails the contract check"
work="$(newdir)"
damaged="$work/drafting-agent-prompt.md"
awk '
  index($0, "5. Check the write scope.") {
    sub(/Check the write scope\./, "Return exactly these fields and no other text.")
    print
    next
  }
  index($0, "6. Return exactly these fields and no other text.") {
    sub(/Return exactly these fields and no other text\./, "Check the write scope.")
  }
  { print }
' "$DRAFTING_PROMPT" > "$damaged"
assert_eq "$DRAFTING_STEPS" "$(drafting_step_numbers "$damaged")" \
  "the damaged copy retains six ordered step numbers"
assert_ne "$DRAFTING_STEP_CONTRACT" "$(drafting_step_contract "$damaged")" \
  "the purpose check rejects requirements moved under the wrong numbers"

test_case "the drafting placeholders carry evidence into the exact report"
assert_eq "$(drafting_table_placeholders "$DRAFTING_PROMPT")" \
  "$(drafting_template_placeholders "$DRAFTING_PROMPT")" \
  "the template uses exactly the placeholders declared by its source table"
assert_eq "$DRAFTING_EVIDENCE_STEPS" \
  "$(drafting_placeholder_steps "$DRAFTING_PROMPT" '{{EVIDENCE}}')" \
  "assigned evidence reaches the single-site and multi-site ticket rules"
assert_eq "$DRAFTING_WAVE_STEPS" \
  "$(drafting_placeholder_steps "$DRAFTING_PROMPT" '{{WAVE}}')" \
  "the negotiated wave is an assigned value and a front-matter key, and nothing else"
assert_eq "$DRAFTING_REPORT_SCHEMA" "$(drafting_report_schema "$DRAFTING_PROMPT")" \
  "the drafting report keeps every field and value contract in order"

test_case "an undeclared report placeholder fails both handoff checks"
work="$(newdir)"
damaged="$work/drafting-agent-prompt.md"
awk '
  /^     evidence: <every citation rendered into ## Evidence>$/ {
    print "     evidence: {{UNDECLARED}}"
    next
  }
  { print }
' "$DRAFTING_PROMPT" > "$damaged"
assert_contains "$(drafting_template_placeholders "$damaged")" '{{UNDECLARED}}' \
  "the copy introduces a placeholder with no source"
assert_ne "$(drafting_table_placeholders "$damaged")" \
  "$(drafting_template_placeholders "$damaged")" \
  "the placeholder comparison rejects the undeclared value"
assert_ne "$DRAFTING_REPORT_SCHEMA" "$(drafting_report_schema "$damaged")" \
  "the report comparison rejects the changed evidence value"

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
