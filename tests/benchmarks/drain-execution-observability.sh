#!/usr/bin/env bash
# Deterministic real-helper execution fixture. This is a wiring and operation-count
# benchmark, not a provider, scheduler, token, or production-throughput benchmark.
set -u

DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

INIT="$REPO_ROOT/src/skills/sift-init/scripts"
DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"
OPERATIONS="$REPO_ROOT/src/operations/sift.sh"
FIXTURE_VERSION=1
PREFIX=LAB
project="$TMPROOT/project"
artifacts="$TMPROOT/artifacts"
worktrees="$TMPROOT/worktrees"
clock_bin="$TMPROOT/clock-bin"
receipts="$artifacts/handoffs.tsv"
statuses="$artifacts/statuses.tsv"
reads="$artifacts/protocol-reads.tsv"
mkdir -p "$project" "$artifacts" "$worktrees" "$clock_bin"
: > "$receipts"; : > "$statuses"; : > "$reads"

fail_fixture() { printf 'execution fixture: %s\n' "$*" >&2; exit 1; }
record_status() { printf '%s\t%s\n' "$1" "$2" >> "$statuses"; }
require_status() { [ "$2" -eq "$3" ] || fail_fixture "$1 status $2, expected $3"; }

cat > "$clock_bin/date" <<'SH'
#!/usr/bin/env bash
case "$*" in
  +%s) printf '%s\n' "${FIXTURE_EPOCH:-1000}" ;;
  '-u +%Y-%m-%dT%H:%M:%SZ') printf '1970-01-01T00:16:40Z\n' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$clock_bin/date"

publish() {
  local record status
  record=$(PATH="$clock_bin:$PATH" SIFT_ROOT="$project" bash "$DRAIN/drain-log.sh" event "$@")
  status=$?
  [ "$status" -eq 0 ] || return "$status"
  printf 'event\t%s\n' "$record" >> "$receipts"
  printf '%s\n' "$record"
}

event_field() {
  local record=$1 key=$2
  printf 'event-fields\t%s\t%s\n' "$record" "$key" >> "$reads"
  SIFT_ROOT="$project" bash "$DRAIN/drain-log.sh" event-fields "$record" |
    awk -F '\t' -v key="$key" '$1 == key {print $2}'
}

event_count() {
  find "$project/.ai/sift/runs/$1/events" -type f -name event.md | wc -l | tr -d '[:space:]'
}

metric() { awk -F '\t' -v key="$2" '$1 == "metric" && $2 == key {print $3}' "$1"; }

prepare() {
  local label=$1 attempt=$2 branch=$3 path=$4 epoch=$5 status
  (cd "$project" && FIXTURE_EPOCH="$epoch" PATH="$clock_bin:$PATH" SIFT_ROOT="$project" \
    SIFT_PREPARE_RUN_ID="$main_run" SIFT_PREPARE_ATTEMPT_ID="$attempt" \
    bash "$DRAIN/prepare-worktree.sh" main "$branch" "$path") \
    > "$artifacts/$label.prepare.out" 2> "$artifacts/$label.prepare.err"
  status=$?
  record_status "prepare:$label" "$status"
  printf 'prepare\t%s\t%s\n' "$label" "$artifacts/$label.prepare.out" >> "$receipts"
  return "$status"
}

git_commit() {
  local tree=$1 message=$2
  git -C "$tree" add src
  git -C "$tree" -c commit.gpgsign=false commit -qm "$message"
  git -C "$tree" rev-parse HEAD
}

land_ticket() {
  local attempt=$1 ticket_id=$2 commit=$3 tree=$4 branch=$5 epoch=$6 span_record span_id status
  span_record=$(publish span-start "run_id=$main_run" "attempt_id=$attempt" actor=coordinator \
    activity=landing "timestamp=$epoch") || return 1
  span_id=$(event_field "$span_record" span_id)
  git -C "$project" -c commit.gpgsign=false cherry-pick "$commit" \
    > "$artifacts/$ticket_id.cherry-pick.out" 2> "$artifacts/$ticket_id.cherry-pick.err"
  status=$?; record_status "land:$ticket_id" "$status"; [ "$status" -eq 0 ] || return "$status"
  publish span-end "run_id=$main_run" "attempt_id=$attempt" "span_id=$span_id" actor=coordinator \
    "timestamp=$epoch" duration=0 outcome=done >/dev/null || return 1
  publish landed "run_id=$main_run" "attempt_id=$attempt" "ticket_id=$ticket_id" actor=coordinator \
    "timestamp=$epoch" "evidence_ref=commit:$commit" >/dev/null || return 1
  span_record=$(publish span-start "run_id=$main_run" "attempt_id=$attempt" actor=coordinator \
    activity=cleanup "timestamp=$epoch") || return 1
  span_id=$(event_field "$span_record" span_id)
  rm -f "$tree/.setup-ran"
  git -C "$project" worktree remove "$tree"
  status=$?; record_status "cleanup:$ticket_id" "$status"; [ "$status" -eq 0 ] || return "$status"
  git -C "$project" branch -D "$branch" >/dev/null
  publish span-end "run_id=$main_run" "attempt_id=$attempt" "span_id=$span_id" actor=coordinator \
    "timestamp=$epoch" duration=0 outcome=done >/dev/null
}

archive_ticket() {
  local ticket_id=$1 status
  (cd "$project" && SIFT_ROOT="$project" bash "$OPERATIONS" archive "$ticket_id" done \
    'Scripted fixture work landed and verified') > "$artifacts/$ticket_id.archive.out" \
    2> "$artifacts/$ticket_id.archive.err"
  status=$?; record_status "archive:$ticket_id" "$status"
  require_status "archive $ticket_id" "$status" 0
}

run_check() {
  local label=$1 run=$2 attempt=$3 check=$4 stage=$5 store=$6 counter=$7 epoch=$8 status
  FIXTURE_EPOCH="$epoch" PATH="$clock_bin:$PATH" SIFT_ROOT="$project" \
    SIFT_EVIDENCE_DIR="$store" CHECK_ENV=fixture-v1 CHECK_PLATFORM=fixture-platform \
    CHECK_COUNTER="$counter" bash "$DRAIN/check-evidence.sh" run "$run" "$attempt" \
    "$check" "$stage" integrated "$project" . -- bash "tests/check-$check.sh" \
    > "$artifacts/$label.check.out" 2> "$artifacts/$label.check.err"
  status=$?; record_status "check:$label" "$status"
  if [ -s "$artifacts/$label.check.out" ]; then
    printf 'evidence\t%s\t%s\n' "$label" "$(cat "$artifacts/$label.check.out")" >> "$receipts"
  fi
  return "$status"
}

test_case "initialize a non-Sift repository with real setup and verification declarations"
git -C "$project" init -q -b main
git -C "$project" config user.name 'Execution Fixture'
git -C "$project" config user.email fixture@example.invalid
mkdir -p "$project/src" "$project/tests" "$project/deps" "$project/settings"
printf 'base\n' > "$project/src/base"
printf 'locked\n' > "$project/deps/lock"
printf 'fixture=true\n' > "$project/settings/check.conf"
cat > "$project/tests/check-suite.sh" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'suite\n' >> "$CHECK_COUNTER"
for input in src/base src/a src/b src/c; do test -f "$input"; done
SH
cat > "$project/tests/check-gate.sh" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'gate\n' >> "$CHECK_COUNTER"
test -f src/repair
SH
cat > "$project/tests/check-compat.sh" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'compat\n' >> "$CHECK_COUNTER"
exit 64
SH
chmod +x "$project/tests/"*.sh
git -C "$project" add src tests deps settings
git -C "$project" -c commit.gpgsign=false commit -qm 'fixture: initial project'

PATH="$clock_bin:$PATH" "$INIT/sift-init.sh" --root "$project" --prefix "$PREFIX" \
  --milestone release > "$artifacts/init.out" 2> "$artifacts/init.err"
status=$?; record_status init "$status"; require_status init "$status" 0
cat > "$project/.ai/sift/config/config.yaml" <<'YAML'
prefix: LAB
verification:
  suite:
    complete: true
    required: true
    stage: development
    scope: integrated
    cwd: .
    command: [bash, tests/check-suite.sh]
    inputs: [src, tests, deps, settings]
    environment: [CHECK_ENV, CHECK_COUNTER]
    platform: CHECK_PLATFORM
  gate:
    complete: true
    required: true
    stage: development
    scope: integrated
    cwd: .
    command: [bash, tests/check-gate.sh]
    inputs: [src, tests, deps, settings]
    environment: [CHECK_ENV, CHECK_COUNTER]
    platform: CHECK_PLATFORM
  compat:
    complete: true
    required: true
    stage: compatibility
    scope: integrated
    cwd: .
    command: [bash, tests/check-compat.sh]
    inputs: [src, tests, deps, settings]
    environment: [CHECK_ENV, CHECK_COUNTER]
    platform: CHECK_PLATFORM
YAML
cat > "$project/.ai/sift/config/worktree-setup" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'branch=%s\nbase=%s\nroot=%s\n' "$SIFT_BRANCH" "$SIFT_BASE_COMMIT" "$SIFT_ROOT" > .setup-ran
case "$SIFT_BRANCH" in *setup-fail*) exit 23 ;; esac
SH
chmod +x "$project/.ai/sift/config/worktree-setup"
ticket "$project" open release/feature LAB-0001 independent 'Independent worker' body=feature > /dev/null
ticket "$project" open release/feature LAB-0002 grouped-a 'Grouped success' body=feature > /dev/null
ticket "$project" open release/feature LAB-0003 grouped-b 'Grouped retry' body=feature > /dev/null
ticket "$project" open release/bug LAB-0004 setup-failure 'Setup failure' body=bug > /dev/null
assert_file "$project/.ai/sift/README.md" "real initialization installs the specification"
assert_eq LAB "$(awk -F ': *' '$1 == "prefix" {print $2; exit}' "$project/.ai/sift/config/config.yaml")" \
  "the fixture uses a non-Sift prefix"

test_case "same-second independent and grouped attempts prepare real worktrees"
run_record=$(publish run-start actor=coordinator timestamp=1000) || fail_fixture 'run start failed'
main_run=$(event_field "$run_record" run_id)
wave_record=$(publish wave-start "run_id=$main_run" wave=1 actor=coordinator timestamp=1000)
wave_id=$(event_field "$wave_record" wave_id)
ind_sitting_record=$(publish sitting "run_id=$main_run" "wave_id=$wave_id" members=LAB-0001 \
  actor=coordinator timestamp=1000)
ind_sitting=$(event_field "$ind_sitting_record" sitting_id)
group_sitting_record=$(publish sitting "run_id=$main_run" "wave_id=$wave_id" members=LAB-0002,LAB-0003 \
  actor=coordinator timestamp=1000)
group_sitting=$(event_field "$group_sitting_record" sitting_id)

(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" "sitting_id=$ind_sitting" \
  members=LAB-0001 actor=worker actor_id=worker-independent work_class=product timestamp=1000 \
  > "$artifacts/independent.attempt") & pid_ind=$!
(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" "sitting_id=$group_sitting" \
  members=LAB-0002,LAB-0003 actor=worker actor_id=worker-group work_class=product timestamp=1000 \
  > "$artifacts/group.attempt") & pid_group=$!
wait "$pid_ind"; status_ind=$?; wait "$pid_group"; status_group=$?
record_status attempt-independent "$status_ind"; record_status attempt-group "$status_group"
require_status attempt-independent "$status_ind" 0; require_status attempt-group "$status_group" 0
ind_attempt=$(event_field "$(cat "$artifacts/independent.attempt")" attempt_id)
group_attempt=$(event_field "$(cat "$artifacts/group.attempt")" attempt_id)
prepare independent "$ind_attempt" worker-independent "$worktrees/independent" 1000
require_status prepare-independent "$?" 0
prepare group "$group_attempt" worker-group "$worktrees/group" 1000
require_status prepare-group "$?" 0
assert_file "$worktrees/independent/.setup-ran" "the real setup hook ran for the independent worker"
assert_file "$worktrees/group/.setup-ran" "the real setup hook ran for the grouped worker"

printf 'independent\n' > "$worktrees/independent/src/a"
ind_commit=$(git_commit "$worktrees/independent" 'worker: independent action')
printf 'group-success\n' > "$worktrees/group/src/b"
group_commit=$(git_commit "$worktrees/group" 'worker: preserve successful group member')
(cd "$worktrees/group" && test -f src/c)
failed_action_status=$?; record_status worker-group-failed-member "$failed_action_status"
require_status worker-group-failed-member "$failed_action_status" 1
publish ticket-outcome "run_id=$main_run" "attempt_id=$ind_attempt" ticket_id=LAB-0001 \
  outcome=done actor=worker work_class=product timestamp=1010 >/dev/null
publish ticket-outcome "run_id=$main_run" "attempt_id=$group_attempt" ticket_id=LAB-0002 \
  outcome=done actor=worker work_class=product timestamp=1010 >/dev/null
publish ticket-outcome "run_id=$main_run" "attempt_id=$group_attempt" ticket_id=LAB-0003 \
  outcome=failed actor=worker work_class=product timestamp=1010 >/dev/null
publish attempt-interrupt "run_id=$main_run" "attempt_id=$group_attempt" reason=interrupted \
  actor=coordinator timestamp=1011 >/dev/null
publish attempt-resume "run_id=$main_run" "attempt_id=$group_attempt" actor=coordinator timestamp=1011 >/dev/null
land_ticket "$ind_attempt" LAB-0001 "$ind_commit" "$worktrees/independent" worker-independent 1012
require_status land-independent "$?" 0
land_ticket "$group_attempt" LAB-0002 "$group_commit" "$worktrees/group" worker-group 1013
require_status land-group "$?" 0
publish attempt-end "run_id=$main_run" "attempt_id=$ind_attempt" outcome=done actor=coordinator timestamp=1014 >/dev/null
publish attempt-end "run_id=$main_run" "attempt_id=$group_attempt" outcome=failed actor=coordinator timestamp=1014 >/dev/null
archive_ticket LAB-0001; archive_ticket LAB-0002

test_case "setup failure is retained and only the failed group member is retried"
setup_sitting_record=$(publish sitting "run_id=$main_run" "wave_id=$wave_id" members=LAB-0004 \
  actor=coordinator timestamp=1015)
setup_sitting=$(event_field "$setup_sitting_record" sitting_id)
setup_attempt_record=$(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" \
  "sitting_id=$setup_sitting" members=LAB-0004 actor=worker actor_id=worker-setup \
  work_class=product timestamp=1015)
setup_attempt=$(event_field "$setup_attempt_record" attempt_id)
prepare setup-failure "$setup_attempt" worker-setup-fail "$worktrees/setup-failure" 1015
setup_status=$?; require_status setup-failure "$setup_status" 3
assert_file "$worktrees/setup-failure/.setup-ran" "the failing setup hook leaves its worktree inspectable"
publish ticket-outcome "run_id=$main_run" "attempt_id=$setup_attempt" ticket_id=LAB-0004 \
  outcome=failed actor=coordinator work_class=product timestamp=1016 >/dev/null
setup_cleanup_record=$(publish span-start "run_id=$main_run" "attempt_id=$setup_attempt" \
  actor=coordinator activity=cleanup timestamp=1017)
setup_cleanup_span=$(event_field "$setup_cleanup_record" span_id)
rm -f "$worktrees/setup-failure/.setup-ran"
git -C "$project" worktree remove "$worktrees/setup-failure"
status=$?; record_status cleanup-setup-failure-worktree "$status"; require_status cleanup-setup-failure-worktree "$status" 0
git -C "$project" branch -D worker-setup-fail >/dev/null
status=$?; record_status cleanup-setup-failure-branch "$status"; require_status cleanup-setup-failure-branch "$status" 0
publish span-end "run_id=$main_run" "attempt_id=$setup_attempt" "span_id=$setup_cleanup_span" \
  actor=coordinator timestamp=1017 duration=0 outcome=done >/dev/null
publish attempt-end "run_id=$main_run" "attempt_id=$setup_attempt" outcome=failed actor=coordinator timestamp=1017 >/dev/null

retry_record=$(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" "sitting_id=$group_sitting" \
  members=LAB-0003 "retry_of=$group_attempt" actor=worker actor_id=worker-retry \
  work_class=product timestamp=1018)
retry_attempt=$(event_field "$retry_record" attempt_id)
wait_record=$(publish wait-start "run_id=$main_run" "attempt_id=$retry_attempt" reason=dependencies \
  wait_class=actionable actor=coordinator timestamp=1018)
wait_id=$(event_field "$wait_record" span_id)
publish wait-end "run_id=$main_run" "attempt_id=$retry_attempt" "span_id=$wait_id" duration=0 \
  actor=coordinator timestamp=1018 >/dev/null
prepare retry "$retry_attempt" worker-retry "$worktrees/retry" 1018
require_status prepare-retry "$?" 0
printf 'retried\n' > "$worktrees/retry/src/c"
retry_commit=$(git_commit "$worktrees/retry" 'worker: retry failed member only')
publish ticket-outcome "run_id=$main_run" "attempt_id=$retry_attempt" ticket_id=LAB-0003 \
  outcome=done actor=worker work_class=product timestamp=1020 >/dev/null
land_ticket "$retry_attempt" LAB-0003 "$retry_commit" "$worktrees/retry" worker-retry 1021
require_status land-retry "$?" 0
publish attempt-end "run_id=$main_run" "attempt_id=$retry_attempt" outcome=done actor=coordinator timestamp=1022 >/dev/null
archive_ticket LAB-0003

test_case "failed gate is repaired by a linked gate-only retry and final evidence invalidates then reuses"
gate_record=$(publish gate "run_id=$main_run" "wave_id=$wave_id" actor=coordinator \
  work_class=infrastructure timestamp=1030)
gate_id=$(event_field "$gate_record" gate_id)
gate_first_record=$(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" "gate_id=$gate_id" \
  members=- actor=gate actor_id=gate-first work_class=infrastructure timestamp=1030)
gate_first=$(event_field "$gate_first_record" attempt_id)
prepare gate-first "$gate_first" gate-first "$worktrees/gate-first" 1030
require_status prepare-gate-first "$?" 0
main_counter="$artifacts/main-check-counter"
run_check gate-first-suite "$main_run" "$gate_first" suite development \
  "$artifacts/main-evidence" "$main_counter" 1030
require_status gate-first-suite "$?" 0
prior_suite_evidence=$(cat "$artifacts/gate-first-suite.check.out")
run_check gate-first-gate "$main_run" "$gate_first" gate development \
  "$artifacts/main-evidence" "$main_counter" 1031
gate_failure_status=$?; require_status gate-first-gate "$gate_failure_status" 1
gate_first_cleanup_record=$(publish span-start "run_id=$main_run" "attempt_id=$gate_first" \
  actor=coordinator activity=cleanup timestamp=1032)
gate_first_cleanup_span=$(event_field "$gate_first_cleanup_record" span_id)
rm -f "$worktrees/gate-first/.setup-ran"
git -C "$project" worktree remove "$worktrees/gate-first"
status=$?; record_status cleanup-gate-first-worktree "$status"; require_status cleanup-gate-first-worktree "$status" 0
git -C "$project" branch -D gate-first >/dev/null
status=$?; record_status cleanup-gate-first-branch "$status"; require_status cleanup-gate-first-branch "$status" 0
publish span-end "run_id=$main_run" "attempt_id=$gate_first" "span_id=$gate_first_cleanup_span" \
  actor=coordinator timestamp=1032 duration=0 outcome=done >/dev/null
publish attempt-end "run_id=$main_run" "attempt_id=$gate_first" outcome=failed actor=gate timestamp=1032 >/dev/null

followup_id=$(cd "$project" && SIFT_ROOT="$project" "$DRAIN/reserve-ids.sh" 1)
status=$?; record_status reserve-followup "$status"; require_status reserve-followup "$status" 0
assert_eq LAB-0005 "$followup_id" "the actual allocator reserves the origin follow-up"
ticket "$project" open release/bug "$followup_id" gate-followup 'Gate repair follow-up' \
  'wave: 1' body=bug > /dev/null
publish link "run_id=$main_run" relation=follow-up "ticket_id=$followup_id" \
  "origin_attempt_id=$gate_first" "origin_gate_id=$gate_id" root_cause=gate-check \
  actor=coordinator timestamp=1033 >/dev/null

gate_retry_record=$(publish attempt-start "run_id=$main_run" "wave_id=$wave_id" "gate_id=$gate_id" \
  members=- "retry_of=$gate_first" actor=gate actor_id=gate-retry \
  work_class=infrastructure timestamp=1034)
gate_retry=$(event_field "$gate_retry_record" attempt_id)
prepare gate-retry "$gate_retry" gate-retry "$worktrees/gate-retry" 1034
require_status prepare-gate-retry "$?" 0
printf 'gate-repair\n' > "$worktrees/gate-retry/src/repair"
repair_commit=$(git_commit "$worktrees/gate-retry" 'gate: repair integrated obligation')
repair_span_record=$(publish span-start "run_id=$main_run" "attempt_id=$gate_retry" actor=gate \
  activity=landing timestamp=1035)
repair_span=$(event_field "$repair_span_record" span_id)
git -C "$project" -c commit.gpgsign=false cherry-pick "$repair_commit" \
  > "$artifacts/gate-repair.cherry-pick.out" 2> "$artifacts/gate-repair.cherry-pick.err"
status=$?; record_status land-gate-repair "$status"; require_status land-gate-repair "$status" 0
publish span-end "run_id=$main_run" "attempt_id=$gate_retry" "span_id=$repair_span" actor=gate \
  timestamp=1035 duration=0 outcome=done >/dev/null

CHECK_ENV=fixture-v1 CHECK_PLATFORM=fixture-platform CHECK_COUNTER="$main_counter" \
  SIFT_ROOT="$project" bash "$DRAIN/check-evidence.sh" validate-declared "$prior_suite_evidence" \
  suite development integrated "$project" > "$artifacts/final-invalidation.tsv" \
  2> "$artifacts/final-invalidation.err"
validation_status=$?; record_status final-invalidation "$validation_status"
require_status final-invalidation "$validation_status" 1
grep -q "$(printf 'reason\tchanged-inputs')" "$artifacts/final-invalidation.tsv" ||
  fail_fixture 'final integration did not record changed-inputs'

run_check gate-retry-suite "$main_run" "$gate_retry" suite development \
  "$artifacts/main-evidence" "$main_counter" 1040
require_status gate-retry-suite "$?" 0
final_suite_evidence=$(cat "$artifacts/gate-retry-suite.check.out")
run_check gate-retry-suite-reuse "$main_run" "$gate_retry" suite development \
  "$artifacts/main-evidence" "$main_counter" 1041
require_status gate-retry-suite-reuse "$?" 0
[ "$(cat "$artifacts/gate-retry-suite-reuse.check.out")" = "$final_suite_evidence" ] ||
  fail_fixture 'matching final evidence was not reused'
run_check gate-retry-gate "$main_run" "$gate_retry" gate development \
  "$artifacts/main-evidence" "$main_counter" 1042
require_status gate-retry-gate "$?" 0

cat > "$artifacts/authorization-grant.txt" <<'TXT'
Fixture grant: defer compatibility execution on fixture-platform until the release review.
TXT
deferral="$artifacts/compatibility-deferral.tsv"
{
  printf '# Compatibility deferral v1\n\n'
  printf 'run_id\t%s\nwave_id\t%s\ncheck_id\tcompat\nstage\tcompatibility\nscope\tintegrated\n' "$main_run" "$wave_id"
  printf 'authorization_ref\t%s\n' "$artifacts/authorization-grant.txt"
  printf 'authorization\tFixture grant: defer compatibility execution on fixture-platform until the release review.\n'
  printf 'reason\tRequired compatibility platform is unavailable in this fixture.\n'
  printf 'outstanding_obligation\tRun tests/check-compat.sh on fixture-platform before release.\n'
  printf 'config_cksum\t%s\n' "$(cksum < "$project/.ai/sift/config/config.yaml")"
} > "$deferral"
publish check "run_id=$main_run" "attempt_id=$gate_retry" check_id=compat stage=compatibility \
  outcome=deferred reason=authorized-deferral "evidence_ref=$deferral" actor=gate timestamp=1043 >/dev/null

cleanup_record=$(publish span-start "run_id=$main_run" "attempt_id=$gate_retry" actor=coordinator \
  activity=cleanup timestamp=1044)
cleanup_span=$(event_field "$cleanup_record" span_id)
rm -f "$worktrees/gate-retry/.setup-ran"
git -C "$project" worktree remove "$worktrees/gate-retry"
status=$?; record_status cleanup-gate-retry-worktree "$status"; require_status cleanup-gate-retry-worktree "$status" 0
git -C "$project" branch -D gate-retry >/dev/null
status=$?; record_status cleanup-gate-retry-branch "$status"; require_status cleanup-gate-retry-branch "$status" 0
publish span-end "run_id=$main_run" "attempt_id=$gate_retry" "span_id=$cleanup_span" \
  actor=coordinator timestamp=1044 duration=0 outcome=done >/dev/null
publish attempt-end "run_id=$main_run" "attempt_id=$gate_retry" outcome=done actor=gate timestamp=1045 >/dev/null
publish wave-end "run_id=$main_run" "wave_id=$wave_id" outcome=done actor=coordinator timestamp=1046 >/dev/null
publish run-end "run_id=$main_run" outcome=done actor=coordinator timestamp=1046 >/dev/null

CHECK_ENV=fixture-v1 CHECK_PLATFORM=fixture-platform CHECK_COUNTER="$main_counter" \
  SIFT_ROOT="$project" bash "$DRAIN/drain-log.sh" report-events "$main_run" "$project" 1050 \
  > "$artifacts/main-report.tsv" 2> "$artifacts/main-report.err"
report_status=$?; record_status report-main "$report_status"; require_status report-main "$report_status" 0
assert_eq 0 "$(metric "$artifacts/main-report.tsv" integrity_errors)" "the composed identity graph has no integrity errors"
assert_eq 2 "$(metric "$artifacts/main-report.tsv" retry_attempts)" \
  "the narrowed member retry and failed gate retry are counted separately"
assert_eq 1 "$(metric "$artifacts/main-report.tsv" authorized_compatibility_deferrals)" \
  "the ten-field record and actual grant authorize one deferral"
assert_eq 3 "$(metric "$artifacts/main-report.tsv" development_verified_product)" \
  "three unique landed product tickets satisfy development verification"
assert_eq 3 "$(metric "$artifacts/main-report.tsv" landed)" \
  "the gate-only repair does not inflate landed ticket count"
assert_eq 3 "$(metric "$artifacts/main-report.tsv" returned_done)" \
  "mixed-group retry history still yields one done result per successful ticket"
assert_eq 0 "$(metric "$artifacts/main-report.tsv" fully_verified_product)" \
  "compatibility deferral never becomes a full pass"
assert_contains "$(cat "$artifacts/main-report.tsv")" \
  "$(printf 'ticket\tLAB-0002\tdone\tproduct\treturned-done\tlanded\tdevelopment-verified\t-\t-')" \
  "the successful mixed-group member remains landed and development verified"
development_ticket_rows=$(awk -F '\t' \
  '$1 == "ticket" && $4 == "product" && $6 == "landed" && $7 == "development-verified" {count++} END {print count+0}' \
  "$artifacts/main-report.tsv")
assert_eq 3 "$development_ticket_rows" \
  "gate-only work creates no synthetic product ticket"
assert_contains "$(cat "$artifacts/main-report.tsv")" "$(printf 'link\tfollow-up\tLAB-0005')" \
  "the report retains the actual gate origin follow-up"
assert_contains "$(cat "$artifacts/main-report.tsv")" "$(printf 'attempt\t%s\t%s\tsitting\t%s\tLAB-0003\t%s' "$retry_attempt" "$wave_id" "$group_sitting" "$group_attempt")" \
  "the retry preserves the sitting but narrows membership to the failed member"

test_case "equivalent final obligations count execution and publication cost"
baseline_run_record=$(publish run-start actor=coordinator timestamp=1100)
baseline_run=$(event_field "$baseline_run_record" run_id)
baseline_wave_record=$(publish wave-start "run_id=$baseline_run" wave=1 actor=coordinator timestamp=1100)
baseline_wave=$(event_field "$baseline_wave_record" wave_id)
baseline_gate_record=$(publish gate "run_id=$baseline_run" "wave_id=$baseline_wave" actor=coordinator timestamp=1100)
baseline_gate=$(event_field "$baseline_gate_record" gate_id)
baseline_attempt_record=$(publish attempt-start "run_id=$baseline_run" "wave_id=$baseline_wave" \
  "gate_id=$baseline_gate" members=- actor=gate work_class=infrastructure timestamp=1100)
baseline_attempt=$(event_field "$baseline_attempt_record" attempt_id)
baseline_counter="$artifacts/baseline-counter"
baseline_before=$(event_count "$baseline_run")
run_check baseline-one "$baseline_run" "$baseline_attempt" suite development \
  "$artifacts/baseline-evidence-one" "$baseline_counter" 1101
require_status baseline-one "$?" 0
run_check baseline-two "$baseline_run" "$baseline_attempt" suite development \
  "$artifacts/baseline-evidence-two" "$baseline_counter" 1102
require_status baseline-two "$?" 0
baseline_after=$(event_count "$baseline_run")
baseline_publications=$((baseline_after - baseline_before))
baseline_executions=$(wc -l < "$baseline_counter" | tr -d '[:space:]')
publish attempt-end "run_id=$baseline_run" "attempt_id=$baseline_attempt" outcome=done actor=gate timestamp=1103 >/dev/null
publish wave-end "run_id=$baseline_run" "wave_id=$baseline_wave" outcome=done actor=coordinator timestamp=1103 >/dev/null
publish run-end "run_id=$baseline_run" outcome=done actor=coordinator timestamp=1103 >/dev/null

reuse_run_record=$(publish run-start actor=coordinator timestamp=1200)
reuse_run=$(event_field "$reuse_run_record" run_id)
reuse_wave_record=$(publish wave-start "run_id=$reuse_run" wave=1 actor=coordinator timestamp=1200)
reuse_wave=$(event_field "$reuse_wave_record" wave_id)
reuse_gate_record=$(publish gate "run_id=$reuse_run" "wave_id=$reuse_wave" actor=coordinator timestamp=1200)
reuse_gate=$(event_field "$reuse_gate_record" gate_id)
reuse_attempt_record=$(publish attempt-start "run_id=$reuse_run" "wave_id=$reuse_wave" \
  "gate_id=$reuse_gate" members=- actor=gate work_class=infrastructure timestamp=1200)
reuse_attempt=$(event_field "$reuse_attempt_record" attempt_id)
reuse_counter="$artifacts/reuse-counter"
reuse_before=$(event_count "$reuse_run")
run_check reuse-one "$reuse_run" "$reuse_attempt" suite development \
  "$artifacts/reuse-evidence" "$reuse_counter" 1201
require_status reuse-one "$?" 0
reuse_evidence=$(cat "$artifacts/reuse-one.check.out")
run_check reuse-two "$reuse_run" "$reuse_attempt" suite development \
  "$artifacts/reuse-evidence" "$reuse_counter" 1202
require_status reuse-two "$?" 0
reuse_after=$(event_count "$reuse_run")
reuse_publications=$((reuse_after - reuse_before))
reuse_executions=$(wc -l < "$reuse_counter" | tr -d '[:space:]')
[ "$(cat "$artifacts/reuse-two.check.out")" = "$reuse_evidence" ] || fail_fixture 'reuse receipt changed'
publish attempt-end "run_id=$reuse_run" "attempt_id=$reuse_attempt" outcome=done actor=gate timestamp=1203 >/dev/null
publish wave-end "run_id=$reuse_run" "wave_id=$reuse_wave" outcome=done actor=coordinator timestamp=1203 >/dev/null
publish run-end "run_id=$reuse_run" outcome=done actor=coordinator timestamp=1203 >/dev/null

assert_eq 2 "$baseline_executions" "isolated stores execute both equivalent obligations"
assert_eq 1 "$reuse_executions" "matching immutable evidence executes one obligation"
assert_eq 8 "$baseline_publications" "each baseline execution publishes invalidation, span pair and result"
assert_eq 5 "$reuse_publications" "reuse adds one decision after one four-event execution"

direct_protocol_reads=$(wc -l < "$reads" | tr -d '[:space:]')
preparation_calls=$(awk -F '\t' '$1 ~ /^prepare:/ {n++} END {print n+0}' "$statuses")
check_executions=$(( $(wc -l < "$main_counter" | tr -d '[:space:]') + baseline_executions + reuse_executions ))
check_requests=$(awk -F '\t' '$1 ~ /^check:/ {n++} END {print n+0}' "$statuses")
# prepare-worktree and each executed check read their generated span receipt once.
all_protocol_reads=$((direct_protocol_reads + preparation_calls + check_executions))
handoff_receipts=$(wc -l < "$receipts" | tr -d '[:space:]')
validation_calls=$(awk -F '\t' '$1 == "final-invalidation" {n++} END {print n+0}' "$statuses")
reporter_validation_calls=$(metric "$artifacts/main-report.tsv" evidence_validations)
total_validation_calls=$((validation_calls + reporter_validation_calls))
main_event_publications=$(event_count "$main_run")
total_event_publications=$(find "$project/.ai/sift/runs" -type f -name event.md | wc -l | tr -d '[:space:]')
find "$project/.ai/sift/runs" -type f -name event.md | LC_ALL=C sort > "$artifacts/event-manifest.txt"
find "$artifacts" -type f | LC_ALL=C sort > "$artifacts/artifact-manifest.txt"
printf 'fixture_version\t%s\nproject_prefix\t%s\n' "$FIXTURE_VERSION" "$PREFIX" > "$artifacts/measurement.tsv"
printf 'baseline_check_executions\t%s\nreuse_check_executions\t%s\n' "$baseline_executions" "$reuse_executions" >> "$artifacts/measurement.tsv"
printf 'baseline_event_publications\t%s\nreuse_event_publications\t%s\n' "$baseline_publications" "$reuse_publications" >> "$artifacts/measurement.tsv"
printf 'main_event_publications\t%s\ntotal_event_publications\t%s\n' \
  "$main_event_publications" "$total_event_publications" >> "$artifacts/measurement.tsv"
printf 'direct_protocol_reads\t%s\nall_protocol_reads\t%s\nhandoff_receipts\t%s\n' \
  "$direct_protocol_reads" "$all_protocol_reads" "$handoff_receipts" >> "$artifacts/measurement.tsv"
printf 'check_requests\t%s\ncheck_executions\t%s\n' "$check_requests" "$check_executions" >> "$artifacts/measurement.tsv"
printf 'explicit_validation_calls\t%s\nreporter_validation_calls\t%s\ntotal_validation_calls\t%s\n' \
  "$validation_calls" "$reporter_validation_calls" "$total_validation_calls" >> "$artifacts/measurement.tsv"
printf 'authorized_compatibility_deferrals\t%s\nfully_verified_product\t%s\n' \
  "$(metric "$artifacts/main-report.tsv" authorized_compatibility_deferrals)" \
  "$(metric "$artifacts/main-report.tsv" fully_verified_product)" >> "$artifacts/measurement.tsv"
printf 'development_verified_product\t%s\nlanded\t%s\nreturned_done\t%s\n' \
  "$(metric "$artifacts/main-report.tsv" development_verified_product)" \
  "$(metric "$artifacts/main-report.tsv" landed)" \
  "$(metric "$artifacts/main-report.tsv" returned_done)" >> "$artifacts/measurement.tsv"

printf 'fixture_version=%s\nproject_prefix=%s\n' "$FIXTURE_VERSION" "$PREFIX"
printf 'baseline_check_executions=%s\nreuse_check_executions=%s\n' "$baseline_executions" "$reuse_executions"
printf 'baseline_event_publications=%s\nreuse_event_publications=%s\n' "$baseline_publications" "$reuse_publications"
printf 'main_event_publications=%s\ntotal_event_publications=%s\n' "$main_event_publications" "$total_event_publications"
printf 'direct_protocol_reads=%s\nall_protocol_reads=%s\n' "$direct_protocol_reads" "$all_protocol_reads"
printf 'handoff_receipts=%s\n' "$handoff_receipts"
printf 'check_requests=%s\ncheck_executions=%s\n' "$check_requests" "$check_executions"
printf 'explicit_validation_calls=%s\nreporter_validation_calls=%s\ntotal_validation_calls=%s\n' \
  "$validation_calls" "$reporter_validation_calls" "$total_validation_calls"
printf 'authorized_compatibility_deferrals=%s\n' "$(metric "$artifacts/main-report.tsv" authorized_compatibility_deferrals)"
printf 'development_verified_product=%s\nlanded=%s\nreturned_done=%s\n' \
  "$(metric "$artifacts/main-report.tsv" development_verified_product)" \
  "$(metric "$artifacts/main-report.tsv" landed)" \
  "$(metric "$artifacts/main-report.tsv" returned_done)"
printf 'fully_verified_product=%s\n' "$(metric "$artifacts/main-report.tsv" fully_verified_product)"
printf 'measurement=scripted helper wiring; no provider or scheduler invoked\n'
if [ "${SIFT_TEST_KEEP:-0}" = 1 ]; then printf 'artifacts=%s\n' "$artifacts"; fi

summary
