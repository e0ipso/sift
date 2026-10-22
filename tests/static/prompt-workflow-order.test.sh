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

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

PROMPT="$REPO_ROOT/src/skills/sift-drain/references/ticket-agent-prompt.md"
DRAFTING_PROMPT="$REPO_ROOT/src/skills/sift-prime/references/drafting-agent-prompt.md"
FOLLOW_HEADING='Step 5: File warranted follow-ups'
REPORT_HEADING='Step 6: Return one final report'
ID_REQUIREMENT='final `tickets filed` field.'
FIELD='tickets filed: <IDs> | none'
WORKER_SCHEMA='status
branch
commits
resolution
verification
issues
deferred to the wave gate
tickets filed
tamper'
DRAFTING_STEPS='1
2
3
4
5
6'
DRAFTING_REFERENCES='STEP 3
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
issue: <decision or correction needed> | none'
DRAFTING_ROWS_STEPS='1'


count_exact() {
  awk -v want="$2" '$0 == want { n++ } END { print n + 0 }' "$1"
}

line_exact() {
  awk -v want="$2" '$0 == want { print NR; exit }' "$1"
}

line_containing() {
  awk -v want="$2" 'index($0, want) { print NR; exit }' "$1"
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
    index($0, "Read the bounded convention sections once for this batch, from .ai/sift/README.md:") {
      print step " read-convention"
    }
    index($0, "Read each distinct assigned schema once.") {
      print step " read-schema"
    }
    index($0, "Create each assigned directory and write the finished ticket atomically") {
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
    section && (/^```$/ || $0 == "Assignment:") { exit }
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

# Follow the named assignment value to the step that writes follow-up metadata.
worker_wave_sites() {
  worker_template "$1" | awk '
    $0 == "Assignment:" { exit }
    /^Step [0-9][0-9]*: / { step = $0; sub(/:.*$/, "", step) }
    step != "" && /WAVE/ { print step }
  '
}

worker_schema_owners() {
  # `issues` is unique to the worker report. A second exact
  # schema would have to copy it, while the gate agents have their own reports.
  grep -l '^  issues:' \
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
# The value is declared at the tail; its fixed-contract reference must still
# reach the filing step so follow-ups cannot lose wave membership.
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

test_case "the batch inputs and compact drafting report remain explicit"
assert_eq "$(drafting_table_placeholders "$DRAFTING_PROMPT")" \
  "$(drafting_template_placeholders "$DRAFTING_PROMPT")" \
  "the template uses exactly the placeholders declared by its source table"
assert_eq "$DRAFTING_ROWS_STEPS" \
  "$(drafting_placeholder_steps "$DRAFTING_PROMPT" '{{TICKET_ROWS}}')" \
  "the batch rows are supplied once, including assigned evidence and waves"
assert_eq "$DRAFTING_REPORT_SCHEMA" "$(drafting_report_schema "$DRAFTING_PROMPT")" \
  "the drafting report keeps every field and value contract in order"

test_case "an undeclared report placeholder fails both handoff checks"
work="$(newdir)"
damaged="$work/drafting-agent-prompt.md"
awk '
  /^     issue: <decision or correction needed> \| none$/ {
    print "     issue: {{UNDECLARED}}"
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
  "the report comparison rejects the changed issue field"

test_case "retained workers get new inputs without another full contract"
reader="$REPO_ROOT/src/skills/sift-drain/scripts/read-context.sh"
run_cmd "$REPO_ROOT" "$reader" "$PROMPT" '## Reuse a worker'
assert_eq 0 "$R_STATUS" "reuse instructions are independently readable"
assert_contains "$R_OUT" '{{SITTING_INPUTS}}' "the reuse handoff supplies the new assignment"
assert_contains "$R_OUT" 'context loss' "missing context requires explicit reconstruction"
assert_contains "$R_OUT" 'contract fingerprint' "reuse checks the canonical contract version"
assert_not_contains "$R_OUT" 'Step 3: Implement and commit each ticket' "reuse does not repeat the full implementation contract"
assert_not_contains "$R_OUT" 'PRIOR ATTEMPT FAILED' "reuse does not preload failure recovery"

test_case "gate stages load independently and carry verification evidence requirements"
gate="$REPO_ROOT/src/skills/sift-drain/references/wave-gate.md"
for heading in '## 1. E2E specialist agent' '## 2. Batch coverage agent' '## 3. Root-cause fixes'; do
  run_cmd "$REPO_ROOT" "$reader" "$gate" "$heading"
  assert_eq 0 "$R_STATUS" "$heading is readable on demand"
  assert_contains "$R_OUT" 'exit codes' "$heading preserves verification status"
  assert_contains "$R_OUT" 'absolute log paths' "$heading leaves full evidence accessible"
  assert_contains "$R_OUT" '8000 content bytes' "$heading bounds returned output"
  assert_not_contains "$R_OUT" '## 4. Wave knowledge capture' "$heading excludes later capture instructions"
done
run_cmd "$REPO_ROOT" "$reader" "$gate" '## 4. Wave knowledge capture'
assert_contains "$R_OUT" 'selected report excerpts' "capture receives selected evidence"
assert_not_contains "$R_OUT" '## 5. Closing the wave' "capture does not preload close"

# Substitute every field with assignment-specific values, including multiline ticket data.
# Literal slicing avoids awk replacement-string interpretation of assignment data.
render_worker() {
  worker_template "$1" | awk -v assignment="$2" '
    {
      line = $0
      while (match(line, /\{\{[^{}]+\}\}/)) {
        key = substr(line, RSTART + 2, RLENGTH - 4)
        value = assignment ":" key
        if (key == "TICKET_BLOCK") value = value "\n" assignment ":second ticket"
        line = substr(line, 1, RSTART - 1) value substr(line, RSTART + RLENGTH)
      }
      print line
    }
  '
}
fixed_prefix() { awk '$0 == "Assignment:" { exit } { print }' "$1"; }
assignment_tail() { awk '$0 == "Assignment:" { inside = 1 } inside' "$1"; }

test_case "different assignments share the complete fixed contract prefix"
work="$(newdir)"
worker_template "$PROMPT" > "$work/template"
assert_ne '' "$(cat "$work/template")" "extract the shipped worker template"
render_worker "$PROMPT" '/tmp/first sitting & branch:one' > "$work/one"
render_worker "$PROMPT" '/different/path & branch:two' > "$work/two"
fixed_prefix "$work/one" > "$work/prefix-one"
fixed_prefix "$work/two" > "$work/prefix-two"
assert_same "$work/prefix-one" "$work/prefix-two" "all assignment substitutions leave identical prefix bytes"
assert_contains "$(cat "$work/prefix-one")" "$REPORT_HEADING" "the shared prefix includes every workflow step"
assert_contains "$(cat "$work/prefix-one")" "$FIELD" "the report schema is part of the shared prefix"
assert_eq 1 "$(count_exact "$work/template" 'Assignment:')" "exactly one assignment boundary exists"
assert_ne "$(assignment_tail "$work/one")" "$(assignment_tail "$work/two")" "distinct assignments actually reach the rendered prompts"
assert_eq "$(worker_table_placeholders "$PROMPT")" "$(placeholders < "$work/template")" "the named input table and rendered fields agree"
assert_not_contains "$(fixed_prefix "$work/template")" '{{' "no dynamic placeholders occur in the contract"
assert_eq "$(worker_table_placeholders "$PROMPT")" "$(assignment_tail "$work/template" | placeholders)" "every declared input is at the end"

assert_eq '{{SITTING_INPUTS}}' "$(worker_template "$PROMPT" '## Reuse a worker')" \
  "the retained-worker message appends only the new assignment information"
for placeholder in $(worker_table_placeholders "$PROMPT"); do
  count=$(assignment_tail "$work/template" | grep -F -c "$placeholder")
  assert_eq 1 "$count" "$placeholder has a single assignment source"
done

test_case "an early assignment substitution breaks the shared prefix proof"
damaged="$work/early.md"
awk '/^Step 1: Orient the sitting$/ { print "Assigned to {{PROJECT_ROOT}}" } { print }' "$PROMPT" > "$damaged"
render_worker "$damaged" one > "$work/bad-one"
render_worker "$damaged" two > "$work/bad-two"
fixed_prefix "$work/bad-one" > "$work/bad-prefix-one"
fixed_prefix "$work/bad-two" > "$work/bad-prefix-two"
assert_ne "$(cat "$work/bad-prefix-one")" "$(cat "$work/bad-prefix-two")" "the proof rejects a substitution anywhere before Assignment"


test_case "worker correlation leaves the attempt live for coordinator integration"
template="$(worker_template "$PROMPT")"
assert_contains "$template" 'RUN_ID: {{RUN_ID}}' "run identity is an assignment input"
assert_contains "$template" 'ATTEMPT_ID: {{ATTEMPT_ID}}' "attempt identity is an assignment input"
assert_contains "$template" 'Do not publish attempt-end' "return cannot terminate coordinator work"
assert_contains "$template" 'check-evidence.sh" run' "scoped checks use the real evidence wrapper"
assert_contains "$template" 'including step 3c' "verification inside implementation has its own timing"
assert_not_contains "$template" 'drain-log.sh phase' "correlated workers do not stamp ticketless legacy phases"
assert_contains "$template" 'origin_attempt_id=$ATTEMPT_ID' "follow-ups retain their actual origin"

# The same fixed-prefix proof applies to specialist and recovery dispatches.
# Every dynamic value belongs after a single Assignment boundary.
assignment_errors() {
  local file="$1" section="$2" body prefix
  body="$(worker_template "$file" "$section")"
  [ -n "$body" ] || { echo 'missing template'; return; }
  [ "$(printf '%s\n' "$body" | grep -c '^Assignment:$')" = 1 ] || echo 'missing or repeated Assignment'
  prefix="$(printf '%s\n' "$body" | awk '$0 == "Assignment:" { exit } { print }')"
  case "$prefix" in *'{{'*) echo 'dynamic prefix' ;; esac
  printf '%s\n' "$body" | grep -Fq 'ATTEMPT_ID: {{ATTEMPT_ID}}' || echo 'missing attempt'
}
test_case "gate and recovery prompts keep changing identities behind fixed prefixes"
for pair in \
  'wave-gate.md|## 1. E2E specialist agent' \
  'wave-gate.md|## 2. Batch coverage agent' \
  'wave-gate.md|## 3. Root-cause fixes' \
  'wave-gate.md|## 4. Wave knowledge capture' \
  'code-review.md|## Reviewer prompt' \
  'ticket-agent-prompt.md|## Resume a stalled sitting' \
  'ticket-agent-prompt.md|## Tamper check-back'
do
  file="$REPO_ROOT/src/skills/sift-drain/references/${pair%%|*}"
  heading="${pair#*|}"
  assert_eq '' "$(assignment_errors "$file" "$heading")" "$heading has a fixed correlated prefix"
done
assert_eq '{{SITTING_INPUTS}}' "$(worker_template "$PROMPT" '## Redispatch on failure')" \
  "retries carry only the complete canonical replacement assignment"
damaged="$(newdir)/gate.md"
awk '/^## 1\. E2E specialist agent$/ { target=1 }
  target && /^```$/ && !hit { print; print "Early {{RUN_ID}}"; hit=1; next } { print }' \
  "$gate" > "$damaged"
assert_contains "$(assignment_errors "$damaged" '## 1. E2E specialist agent')" \
  'dynamic prefix' "an early correlation value is rejected"

# Execute the shipped handoff blocks rather than maintaining a second CLI model.
# This is an API/lifetime guard, not task 7's throughput measurement fixture.
execution_block() {
  awk -v tag="<!-- @EXECUTION: $2 -->" '
    $0 == tag { seek=1; next }
    seek && /^```/ { inside=1; seek=0; next }
    inside && /^```/ { exit }
    inside { print }
  ' "$1"
}
test_case "published contract commands keep return landing cleanup and final checks in valid lifetimes"
management="$REPO_ROOT/src/skills/sift-drain/references/run-management.md"
proof="$(newdir)/handoff.sh"
cat > "$proof" <<'SETUP'
set -eu
export SIFT_ROOT="$1"
export SIFT_EVIDENCE_DIR="$SIFT_ROOT/../evidence"
SCRIPTS_DIR="$2"
cd "$SIFT_ROOT"
WAVE=1 WORK_CLASS=product MEMBERS=SFT-0001 RETRY_OF='' EXTERNAL_ID=''
git init -q
git config user.name Fixture
git config user.email fixture@example.invalid
mkdir -p .ai/sift/config tests
printf '.ai/\n' > .git/info/exclude
cat > .ai/sift/config/config.yaml <<'CONFIG'
prefix: SFT
verification:
  suite:
    complete: true
    required: true
    stage: development
    scope: integrated
    cwd: .
    command: [bash, tests/check.sh]
    inputs: [tests]
    environment: [CHECK_ENV]
    platform: CHECK_PLATFORM
CONFIG
printf 'exit 0\n' > tests/check.sh
git add tests/check.sh
git commit -qm initial
BASE_BRANCH=$(git symbolic-ref --short HEAD)
BRANCH=worker PROJECT_ROOT="$SIFT_ROOT/../prepared"
SETUP
for block in run-wave sitting attempt preparation; do
  body="$(execution_block "$management" "$block")"
  assert_ne '' "$body" "$block command contract is nonempty"
  printf '%s\n' "$body" >> "$proof"
done
cat >> "$proof" <<'RETURN'
TICKET_ID=SFT-0001 TICKET_OUTCOME=done TICKET_WORK_CLASS=product
RETURN
execution_block "$management" ticket-outcome >> "$proof"
printf '%s\n' 'ACTOR=coordinator ACTIVITY=landing SPAN_OUTCOME=done' >> "$proof"
execution_block "$management" span-start >> "$proof"
printf '%s\n' 'LANDED_COMMIT=$(git rev-parse HEAD)' >> "$proof"
execution_block "$management" landed >> "$proof"
execution_block "$management" span-end >> "$proof"
printf '%s\n' 'ACTIVITY=cleanup' >> "$proof"
execution_block "$management" span-start >> "$proof"
execution_block "$management" span-end >> "$proof"
printf '%s\n' 'ATTEMPT_OUTCOME=done' >> "$proof"
execution_block "$management" attempt-end >> "$proof"
for block in gate gate-attempt; do execution_block "$management" "$block" >> "$proof"; done
cat >> "$proof" <<'CHECK'
CHECK_ID=suite STAGE=development SCOPE=integrated LOGICAL_CWD=.
CHECK_COMMAND=(bash tests/check.sh)
export CHECK_ENV=fixture CHECK_PLATFORM=fixture
CHECK
printf 'EVIDENCE=$(\n' >> "$proof"
execution_block "$management" check-run >> "$proof"
printf ')\n' >> "$proof"
execution_block "$management" check-validate >> "$proof"
execution_block "$management" attempt-end >> "$proof"
cat >> "$proof" <<'CLOSE'
"$SCRIPTS_DIR/drain-log.sh" event wave-end "run_id=$RUN_ID" "wave_id=$WAVE_ID" outcome=done actor=coordinator
"$SCRIPTS_DIR/drain-log.sh" report-events "$RUN_ID" "$PROJECT_ROOT"
CLOSE
root="$(newdir)/project"; mkdir "$root"
run_cmd "$REPO_ROOT" bash "$proof" "$root" "$REPO_ROOT/src/skills/sift-drain/scripts"
assert_eq 0 "$R_STATUS" "documented publication preparation check and validation interfaces execute"
assert_contains "$R_OUT" "$(printf 'metric\tintegrity_errors\t0')" "return followed by landing and cleanup has no lifetime errors"
assert_contains "$R_OUT" "$(printf 'valid\ttrue')" "final integrated declaration validation is real"
assert_contains "$R_OUT" "$(printf 'metric\tcompleted_attempts\t2')" "ticket and gate attempts terminate after their owned work"

test_case "manual span closure preserves malformed clock gaps without fabricated terminals"
clockproof="$(newdir)/clock.sh"
cat > "$clockproof" <<'SETUP'
set -eu
export SIFT_ROOT="$1"
SCRIPTS_DIR="$2"
RUN_ID=clock-run ATTEMPT_ID=clock-attempt SPAN_ID=clock-span SPAN_START=1000
ACTOR=worker SPAN_OUTCOME=done
date() { printf '1001\nbad\n'; }
SETUP
execution_block "$management" span-end >> "$clockproof"
run_cmd "$REPO_ROOT" bash "$clockproof" "$root" "$REPO_ROOT/src/skills/sift-drain/scripts"
assert_contains "$R_ERR" 'remains incomplete' "malformed clock is diagnosed before publication or arithmetic"
assert_not_contains "$R_ERR" 'integer expression expected' "malformed clock never reaches numeric comparison"
assert_no_dir "$root/.ai/sift/runs/clock-run" "bad clock cannot publish a fabricated terminal"

summary
