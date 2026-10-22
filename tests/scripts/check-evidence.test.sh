#!/usr/bin/env bash
# Real command counts and mutations exercise evidence decisions, not a cache model.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/check-evidence.sh"
LOG="$REPO_ROOT/src/skills/sift-drain/scripts/drain-log.sh"

fixture() {
  d=$(newdir)
  project="$d/project"
  mkdir -p "$project/.ai/sift/config" "$project/src" "$project/tests" "$project/deps" "$d/evidence"
  cat > "$project/.ai/sift/config/config.yaml" <<'EOF'
prefix: ABCD
verification:
  suite:
    complete: true
    required: true
    stage: development
    scope: integrated
    cwd: .
    command: [bash, tests/check.sh, 'two words', '', '*']
    inputs: [src, tests, deps, settings]
    environment: [CHECK_ENV]
    platform: CHECK_PLATFORM
EOF
  printf 'source\n' > "$project/src/code"
  printf 'dependency\n' > "$project/deps/lock"
  printf 'configuration\n' > "$project/settings"
  cat > "$project/tests/check.sh" <<'EOF'
#!/usr/bin/env bash
printf 'executed\n' >> "$COUNTER"
printf '<%s>\n' "$@"
EOF
  export SIFT_ROOT="$project" SIFT_EVIDENCE_DIR="$d/evidence"
  export CHECK_ENV=toolchain-v1 CHECK_PLATFORM=fixture-platform COUNTER="$d/count"
  run_id=run-fixture
  attempt='attempt-1'
}
execute() {
  run_cmd "$project" bash "$CHECK" run "$run_id" "$attempt" suite development integrated "$project" . -- bash tests/check.sh 'two words' '' '*'
}
validate() {
  run_cmd "$project" bash "$CHECK" validate "$1" suite development integrated "$project" . -- bash tests/check.sh 'two words' '' '*'
}
field() { awk -F '\t' -v key="$2" '$1 == key {print $2}' "$1"; }

test_case "execution preserves argv and reuse retains immutable producing evidence"
fixture
execute
assert_eq 0 "$R_STATUS" 'first check succeeds'
evidence=$R_OUT
assert_file "$evidence" 'stdout names immutable evidence'
if [ -f "$evidence" ]; then
  assert_eq executed "$(cat "$COUNTER")" 'first request executes once'
  assert_eq $'<two words>\n<>\n<*>' "$(cat "${evidence%/*}/raw.log")" 'argv boundaries survive and raw log is outside checkout'
  prior=$(tree_digest "$d/evidence")
  attempt='attempt-2'
  execute
  assert_eq 0 "$R_STATUS" 'second request succeeds'
  assert_eq "$evidence" "$R_OUT" 'reuse points at original producing evidence'
  assert_eq executed "$(cat "$COUNTER")" 'identical request does not execute'
  assert_eq "$prior" "$(tree_digest "$d/evidence")" 'reuse never overwrites evidence'
  assert_eq attempt-1 "$(field "$evidence" attempt_id)" 'producer attribution is retained'
  tracker_before=$(tree_digest "$project/.ai/sift")
  validate "$evidence"
  assert_eq 0 "$R_STATUS" 'read-only validator confirms current integrated scope'
  assert_eq "$tracker_before" "$(tree_digest "$project/.ai/sift")" 'validation publishes no events'
  assert_eq "$prior" "$(tree_digest "$d/evidence")" 'validation does not write evidence'
  assert_contains "$R_OUT" $'reason\tunchanged-inputs' 'validation gives a machine-readable reason'
  events=$(find "$project/.ai/sift/runs" -name event.md)
  assert_ne '' "$events" 'real public event interface is exercised'
  while IFS= read -r event; do
    run_cmd "$project" bash "$LOG" event-validate "$event"
    assert_eq 0 "$R_STATUS" 'each emitted event obeys the task 1 grammar'
  done <<< "$events"
fi

test_case "a one-word command runs with the callers umask and validates"
fixture
sed "s/    command:.*/    command: [true]/" "$project/.ai/sift/config/config.yaml" > "$d/config"
mv "$d/config" "$project/.ai/sift/config/config.yaml"
run_cmd "$project" bash "$CHECK" run "$run_id" "$attempt" suite development integrated "$project" . -- true
assert_eq 0 "$R_STATUS" 'a command with no arguments is accepted'
if [ -f "$R_OUT" ]; then
  evidence=$R_OUT
  run_cmd "$project" bash "$CHECK" validate "$evidence" suite development integrated "$project" . -- true
  assert_eq 0 "$R_STATUS" 'minimal validation invocation is accepted'
fi
fixture
cat >> "$project/tests/check.sh" <<'EOF'
umask
EOF
expected_mask=$(umask)
execute
assert_eq 0 "$R_STATUS" 'umask probe executes'
if [ -f "$R_OUT" ]; then
  assert_eq "$expected_mask" "$(tail -1 "${R_OUT%/*}/raw.log")" 'evidence capture preserves command environment'
fi

test_case "counter fixtures invalidate every declared input dimension"
fixture
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  count=1
  for dimension in source dependency test configuration environment platform membership mode symlink log; do
    case "$dimension" in
      source) printf 'edit\n' >> "$project/src/code" ;;
      dependency) printf 'edit\n' >> "$project/deps/lock" ;;
      test) printf '# changed test\n' >> "$project/tests/check.sh" ;;
      configuration) printf 'edit\n' >> "$project/settings" ;;
      environment) CHECK_ENV=toolchain-v2 ;;
      platform) CHECK_PLATFORM=platform-v2 ;;
      membership) printf 'untracked\n' > "$project/src/new" ;;
      mode) chmod +x "$project/src/code" ;;
      symlink) ln -s code "$project/src/link" ;;
      log) printf 'tampered log\n' >> "${evidence%/*}/raw.log" ;;
    esac
    validate "$evidence"
    assert_eq 1 "$R_STATUS" "$dimension change invalidates read-only validation"
    execute
    assert_eq 0 "$R_STATUS" "$dimension change still executes successfully"
    assert_ne "$evidence" "$R_OUT" "$dimension change produces new immutable evidence"
    evidence=$R_OUT
    count=$((count + 1))
    assert_eq "$count" "$(wc -l < "$COUNTER" | tr -d ' ')" "$dimension change increments actual command count"
  done
fi

test_case "symlink target modes and uncertain link chains cannot hide input changes"
fixture
printf 'external\n' > "$d/external"
ln -s "$d/external" "$project/src/link"
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  validate "$evidence"
  assert_eq 0 "$R_STATUS" 'direct regular-file symlink is reusable'
  chmod +x "$d/external"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'symlink target executable mode is part of input identity'
  execute
  evidence=$R_OUT
  mv "$d/external" "$d/target"
  ln -s target "$d/external"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'an uncertain chain cannot inherit direct-file evidence'
fi

test_case "new commits and separately prepared trees reuse identical relevant inputs"
fixture
git -C "$project" init -q
git -C "$project" config user.name Fixture
git -C "$project" config user.email fixture@example.invalid
git -C "$project" add src tests deps settings
git -C "$project" -c commit.gpgsign=false commit -qm 'test: initial input fixture'
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  git -C "$project" -c commit.gpgsign=false commit --allow-empty -qm 'test: unrelated commit'
  execute
  assert_eq "$evidence" "$R_OUT" 'new commit alone does not invalidate inputs'
  run_cmd "$project" git worktree add --detach "$d/prepared" HEAD
  assert_eq 0 "$R_STATUS" 'a real separate worktree is prepared'
  run_cmd "$d/prepared" bash "$CHECK" run "$run_id" attempt-prepared suite development integrated "$d/prepared" . -- bash tests/check.sh 'two words' '' '*'
  assert_eq 0 "$R_STATUS" 'prepared-tree request succeeds'
  assert_eq "$evidence" "$R_OUT" 'physical checkout path is excluded from logical identity'
  assert_eq executed "$(cat "$COUNTER")" 'three requests execute exactly once'
  printf 'integrated change\n' >> "$project/src/code"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'final integrated inputs reject stale worker evidence'
fi

test_case "failed and changing checks retain results but cannot satisfy final evidence"
fixture
printf 'exit 7\n' >> "$project/tests/check.sh"
execute
assert_eq 7 "$R_STATUS" 'command failure status is preserved'
evidence=$R_OUT
if [ -f "$evidence" ]; then
  assert_eq 7 "$(field "$evidence" exit_status)" 'exact nonzero result is stored'
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'failure cannot satisfy validation'
  assert_contains "$R_OUT" $'reason\tfailed-evidence' 'failure reason is reported'
  execute
  assert_eq 7 "$R_STATUS" 'retry still reports command failure'
  assert_eq 2 "$(wc -l < "$COUNTER" | tr -d ' ')" 'failed evidence never skips execution'
fi
fixture
printf 'printf "mutation\\n" >> src/code\n' >> "$project/tests/check.sh"
execute
assert_eq 0 "$R_STATUS" 'a mutating command retains its successful exit status'
evidence=$R_OUT
if [ -f "$evidence" ]; then
  assert_eq false "$(field "$evidence" stable)" 'before/after change is captured'
  assert_eq unstable-inputs "$(field "$evidence" reason)" 'instability reason is immutable'
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'success with unstable inputs is not final evidence'
  execute
  assert_eq 2 "$(wc -l < "$COUNTER" | tr -d ' ')" 'unstable evidence never skips execution'
fi

test_case "unknown dependencies and uncertain environments execute conservatively"
for uncertainty in missing-declaration incomplete missing-environment missing-platform unknown-key duplicate-key malformed-override missing-input directory-link; do
  fixture
  config="$project/.ai/sift/config/config.yaml"
  case "$uncertainty" in
    missing-declaration) printf 'prefix: ABCD\n' > "$config" ;;
    incomplete) sed 's/complete: true/complete: false/' "$config" > "$d/config"; mv "$d/config" "$config" ;;
    missing-environment) unset CHECK_ENV ;;
    missing-platform) unset CHECK_PLATFORM ;;
    unknown-key) printf '    guessed: true\n' >> "$config" ;;
    duplicate-key) printf '    complete: true\n' >> "$config" ;;
    malformed-override) printf 'verification: {}\n' >> "$config" ;;
    missing-input) rm "$project/deps/lock"; rmdir "$project/deps" ;;
    directory-link) mkdir "$d/external-dir"; ln -s "$d/external-dir" "$project/src/link" ;;
  esac
  execute
  assert_eq 0 "$R_STATUS" "$uncertainty permits normal execution"
  evidence=$R_OUT
  if [ -f "$evidence" ]; then
    validate "$evidence"
    assert_eq 1 "$R_STATUS" "$uncertainty cannot satisfy final validation"
    execute
    assert_eq 2 "$(wc -l < "$COUNTER" | tr -d ' ')" "$uncertainty prevents reuse"
    assert_ne "$evidence" "$R_OUT" "$uncertainty retains each producing attempt"
  fi
done

test_case "expected argv scope and stage are independent validation obligations"
fixture
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  run_cmd "$project" bash "$CHECK" validate "$evidence" suite development integrated "$project" . -- bash tests/check.sh changed
  assert_eq 1 "$R_STATUS" 'different command cannot validate old evidence'
  run_cmd "$project" bash "$CHECK" validate "$evidence" suite compatibility integrated "$project" . -- bash tests/check.sh 'two words' '' '*'
  assert_eq 1 "$R_STATUS" 'development does not stand in for compatibility'
  run_cmd "$project" bash "$CHECK" validate "$evidence" suite development other-scope "$project" . -- bash tests/check.sh 'two words' '' '*'
  assert_eq 1 "$R_STATUS" 'narrow scope cannot stand in for another obligation'
  run_cmd "$project" bash "$CHECK" run "$run_id" attempt-new-command suite development integrated "$project" . -- bash tests/check.sh changed
  assert_eq 0 "$R_STATUS" 'new argv executes'
  assert_ne "$evidence" "$R_OUT" 'changed argv produces different evidence'
  assert_eq 2 "$(wc -l < "$COUNTER" | tr -d ' ')" 'argv change increments actual count'
  rm "${evidence%/*}/raw.log"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'missing raw log cannot satisfy evidence'
  assert_contains "$R_OUT" $'reason\tmissing-evidence' 'missing-log reason is explicit'
fi

test_case "evidence guard runs before writes and validation rejects checkout-local copies"
fixture
SIFT_EVIDENCE_DIR="$project/forbidden"
execute
assert_eq 2 "$R_STATUS" 'checkout-local evidence store is rejected'
assert_no_dir "$project/forbidden" 'guard precedes evidence directory creation'
assert_no_dir "$project/.ai/sift/runs" 'guard precedes event publication'
assert_no_file "$COUNTER" 'guard precedes command execution'
SIFT_EVIDENCE_DIR="$d/evidence"
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  mkdir "$project/local-copy"
  cp "${evidence%/*}/"* "$project/local-copy/"
  validate "$project/local-copy/evidence.md"
  assert_eq 1 "$R_STATUS" 'checkout-local evidence cannot validate even with matching hashes'
  printf 'exit_status\t0\n' >> "$evidence"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'duplicate metadata does not establish a pass'
fi

test_case "reporter validation obtains the required argv from project configuration"
fixture
execute
evidence=$R_OUT
if [ -f "$evidence" ]; then
  before=$(tree_digest "$project/.ai/sift")
  evidence_before=$(tree_digest "$d/evidence")
  run_cmd "$project" bash "$CHECK" validate-declared "$evidence" suite development integrated "$project"
  assert_eq 0 "$R_STATUS" 'reporter validates the declared obligation without supplying trusted event argv'
  assert_contains "$R_OUT" $'producing_attempt\tattempt-1' 'validated producer is returned'
  assert_eq "$before" "$(tree_digest "$project/.ai/sift")" 'reporter validation leaves tracker bytes untouched'
  assert_eq "$evidence_before" "$(tree_digest "$d/evidence")" 'reporter validation leaves evidence bytes untouched'
  assert_eq executed "$(cat "$COUNTER")" 'reporter validation executes no command'
  sed "s/    command:.*/    command: [true]/" "$project/.ai/sift/config/config.yaml" > "$d/config"
  mv "$d/config" "$project/.ai/sift/config/config.yaml"
  run_cmd "$project" bash "$CHECK" validate-declared "$evidence" suite development integrated "$project"
  assert_eq 1 "$R_STATUS" 'a changed declared command invalidates reporter evidence'
  execute
  assert_eq 0 "$R_STATUS" 'out-of-declaration commands may still execute'
  if [ -f "$R_OUT" ]; then
    assert_eq false "$(field "$R_OUT" complete)" 'an undeclared command cannot establish the required check'
  fi
fi

test_case "the documented declaration executes through the public helper"
fixture
# Single owning caller: extract the normative block, not a hand-maintained copy.
declaration=$(readme_check_declaration)
assert_contains "$declaration" 'verification:' 'the normative declaration extractor is nonempty'
printf 'prefix: ABCD\n%s\n' "$declaration" > "$project/.ai/sift/config/config.yaml"
run_cmd "$project" bash "$CHECK" -- run "$run_id" "$attempt" suite development integrated "$project" . -- bash tests/check.sh
assert_eq 0 "$R_STATUS" 'documented command and configuration execute'
evidence=$R_OUT
assert_file "$evidence" 'documented execution produces evidence'
if [ -f "$evidence" ]; then
  run_cmd "$project" bash "$CHECK" -- validate-declared "$evidence" suite development integrated "$project"
  assert_eq 0 "$R_STATUS" 'documented evidence validates against the declaration'
fi

test_case "a reworded declaration anchor cannot select neighbouring configuration"
work=$(newdir)
damaged="$(readme_reworded "$work" "$ANCHOR_CHECK_DECLARATION")" || damaged=''
assert_ne "" "$damaged" 'the declaration anchor exists in README.md'
README="${damaged:-$README}"
assert_eq "" "$(readme_check_declaration)" \
  'the extractor returns nothing when its named anchor is obsolete'
README="$REPO_ROOT/README.md"
assert_contains "$(readme_check_declaration)" 'verification:' \
  'restoring the normative README restores the exact declaration'

test_case "argv bytes are retained without evaluation even outside declaration syntax"
fixture
run_cmd "$project" bash "$CHECK" run "$run_id" "$attempt" suite development integrated "$project" . -- bash tests/check.sh $'line\nbreak' '$(touch sentinel)' '--' 'a,b' "quote'"
assert_eq 0 "$R_STATUS" 'arbitrary argv still executes conservatively'
evidence=$R_OUT
assert_file "$evidence" 'arbitrary argv still produces diagnostics'
assert_no_file "$project/sentinel" 'no argument is evaluated as shell code'
if [ -f "$evidence" ]; then
  printf '%s\0' bash tests/check.sh $'line\nbreak' '$(touch sentinel)' '--' 'a,b' "quote'" > "$d/argv"
  assert_same "$d/argv" "${evidence%/*}/argv.nul" 'NUL-delimited argv retains every byte and boundary'
  assert_eq false "$(field "$evidence" complete)" 'argv outside the declaration cannot satisfy the obligation'
fi

test_case "membership and symlink identities include empty directories and target names"
fixture
printf 'same content\n' > "$d/one"
cp "$d/one" "$d/two"
ln -s "$d/one" "$project/src/link"
execute
evidence=$R_OUT
assert_file "$evidence" 'symlink fixture produces reusable evidence'
if [ -f "$evidence" ]; then
  rm "$project/src/link"
  ln -s "$d/two" "$project/src/link"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'retargeting a link invalidates even when target content is identical'
  execute
  evidence=$R_OUT
  mkdir "$project/src/empty"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'new empty directory is discovered input membership'
  execute
  evidence=$R_OUT
  rmdir "$project/src/empty"
  validate "$evidence"
  assert_eq 1 "$R_STATUS" 'removed membership invalidates evidence'
fi

test_case "controlled end clocks leave explicit gaps without losing command status"
for clock_case in backwards unavailable malformed empty leading-zero oversized equal forward; do
  for command_status in 0 7; do
    fixture
    mkdir "$d/bin"
    export CHECK_CLOCK_DONE="$d/command-finished" CHECK_CLOCK_CASE="$clock_case"
    cat > "$d/bin/date" <<'EOF'
#!/usr/bin/env bash
[ "$1" = +%s ] || exit 1
if [ ! -f "$CHECK_CLOCK_DONE" ]; then printf '100\n'; exit 0; fi
case "$CHECK_CLOCK_CASE" in
  backwards) printf '90\n' ;;
  unavailable) exit 1 ;;
  malformed) printf 'not-a-clock\n' ;;
  empty) printf '\n' ;;
  leading-zero) printf '0105\n' ;;
  oversized) printf '9999999999999999\n' ;;
  equal) printf '100\n' ;;
  forward) printf '105\n' ;;
esac
EOF
    chmod +x "$d/bin/date"
    printf 'touch "$CHECK_CLOCK_DONE"\nexit %s\n' "$command_status" >> "$project/tests/check.sh"
    PATH="$d/bin:$PATH" execute
    actual_status=$R_STATUS; receipt=$R_OUT; diagnostic=$R_ERR
    evidence=$(find "$d/evidence" -name evidence.md)
    assert_file "$evidence" "$clock_case/$command_status retains published content evidence"
    assert_file "$CHECK_CLOCK_DONE" "$clock_case/$command_status reads its end clock after the real command"
    assert_eq executed "$(cat "$COUNTER")" "$clock_case/$command_status executes exactly once"
    starts=0; ends=0; results=0; observed_duration=''
    while IFS= read -r event; do
      fields=$(bash "$LOG" event-fields "$event")
      assert_eq 0 "$?" "$clock_case/$command_status retains valid public events"
      kind=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="kind" {print $2}')
      case "$kind" in
        span-start) starts=$((starts + 1)) ;;
        span-end)
          ends=$((ends + 1))
          observed_duration=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="duration" {print $2}') ;;
        check)
          outcome=$(printf '%s\n' "$fields" | awk -F '\t' '$1=="outcome" {print $2}')
          case "$outcome" in passed|failed) results=$((results + 1)) ;; esac ;;
      esac
    done < <(find "$project/.ai/sift/runs" -name event.md)
    assert_eq 1 "$starts" "$clock_case/$command_status preserves the real span start"
    case "$clock_case" in
      equal|forward)
        assert_eq "$command_status" "$actual_status" "$clock_case/$command_status preserves result with valid telemetry"
        assert_eq "$evidence" "$receipt" "$clock_case/$command_status returns the receipt"
        assert_eq 1 "$ends" "$clock_case/$command_status publishes an observed span end"
        expected_duration=0; [ "$clock_case" != forward ] || expected_duration=5
        assert_eq "$expected_duration" "$observed_duration" "$clock_case/$command_status records actual elapsed seconds"
        assert_eq 1 "$results" "$clock_case/$command_status publishes the command result" ;;
      *)
        expected_status=$command_status; [ "$expected_status" -ne 0 ] || expected_status=2
        assert_eq "$expected_status" "$actual_status" "$clock_case/$command_status preserves failure or reports successful-command telemetry error"
        assert_eq '' "$receipt" "$clock_case/$command_status does not claim complete publication"
        assert_contains "$diagnostic" 'instrumentation gap:' "$clock_case/$command_status explains incomplete instrumentation"
        assert_contains "$diagnostic" 'remains incomplete' "$clock_case/$command_status names the open span"
        detail='end clock malformed'
        case "$clock_case" in
          backwards) detail='end clock moved backwards' ;;
          unavailable) detail='end clock unavailable' ;;
        esac
        assert_contains "$diagnostic" "$detail" "$clock_case/$command_status identifies the clock failure"
        assert_eq 0 "$ends" "$clock_case/$command_status never fabricates a terminal timestamp or duration"
        assert_eq 0 "$results" "$clock_case/$command_status leaves the timed result missing" ;;
    esac
    if [ -f "$evidence" ]; then
      assert_eq "$command_status" "$(field "$evidence" exit_status)" "$clock_case/$command_status records the actual command status"
      before=$(tree_digest "$d/evidence")
      run_cmd "$project" bash "$CHECK" validate-declared "$evidence" suite development integrated "$project"
      expected_valid=0; [ "$command_status" -eq 0 ] || expected_valid=1
      assert_eq "$expected_valid" "$R_STATUS" "$clock_case/$command_status validates content independently of elapsed-time evidence"
      assert_eq "$before" "$(tree_digest "$d/evidence")" "$clock_case/$command_status validation does not rewrite evidence"
      if [ "$command_status" -eq 0 ]; then
        # A healthy later clock may publish reuse, but cannot repair the old span.
        execute
        assert_eq 0 "$R_STATUS" "$clock_case/$command_status allows a later content-valid reuse"
        assert_eq "$evidence" "$R_OUT" "$clock_case/$command_status reuse retains the original producer"
        assert_eq executed "$(cat "$COUNTER")" "$clock_case/$command_status reuse does not rerun the command"
        assert_eq "$before" "$(tree_digest "$d/evidence")" "$clock_case/$command_status reuse leaves immutable evidence untouched"
      fi
    fi
  done
done
unset CHECK_CLOCK_DONE CHECK_CLOCK_CASE

summary
