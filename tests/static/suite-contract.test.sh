#!/usr/bin/env bash
# The suite's own promises, asserted rather than described (SFT-0008).
#
# tests/README.md and run.sh's usage block make claims on behalf of every file
# here: the suite needs no installable dependency, it is deterministic, every
# fixture lives under a temporary directory that is removed on exit — including
# on failure — nothing in the suite writes inside the repository, every
# assertion helper reports a failure when its claim is false, and
# SIFT_TEST_VERBOSE streams the assertions a green file otherwise keeps to
# itself. They are the same claims the convention makes about its recipes, so
# they are held to the same bar: this file breaks them on purpose and checks the
# harness keeps them anyway. For every promise either document makes about the
# harness, exactly one case here fails when it is broken.
#
# The fixture cases work by running a generated child test file, reading the
# TMPROOT it announces, and looking for it afterwards from out here. A leaked
# temporary tree is otherwise invisible — the suite passes, and the machine
# fills up one run at a time.
#
# The dependency case runs a real test file with PATH pointing at a symlink farm
# holding nothing but the baseline utilities listed below. That list IS the
# contract: adding a name to it is a decision to depend on that tool, which is
# why it is spelled out here rather than derived from whatever the machine has.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

SUITE="$REPO_ROOT/tests"

# The baseline Unix userland AGENTS.md permits: POSIX utilities present on any
# GNU or BSD system, plus bash itself. No jq, no xmllint, no language runtime,
# no gawk/mawk/nawk, no dash — every one of those is an optional extra a case
# must guard with `command -v`.
BASELINE='bash sh env printf test true false expr
mktemp mkdir rmdir rm mv cp ln touch chmod ls find
cat head tail cut tr sort uniq wc grep sed awk
basename dirname date cksum cmp diff od tee sleep'

# The paths the no-writes digest below does NOT walk. This list has the same
# standing as BASELINE: naming a path here is a decision that the suite is
# allowed to disturb it, so every entry carries its reason and there are only
# two.
#   .git                   git rewrites its own index, logs and packs for
#                          reasons that have nothing to do with the suite, and a
#                          cksum over the object store would cost more than the
#                          rest of this file put together.
#   .ai/kenkeep/_sessions  written by session-capture hooks that run outside the
#                          suite entirely, so a live agent session would turn the
#                          case red for something the suite did not do.
DIGEST_EXCLUDE='.git
.ai/kenkeep/_sessions'

# --- Fixture cleanup ---------------------------------------------------------

# make_child <pass|fail|die|helpers> — a minimal test file that announces its
# TMPROOT. One generator, one mode per shape of child: a second generator would
# be a second thing to keep in step with the harness.
make_child() {
  local mode="$1" f
  f="$(mktemp "$TMPROOT/child-$mode.XXXXXX")"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -u\n'
    printf '. "%s/lib/harness.sh"\n' "$SUITE"
    printf 'echo "CHILD_TMPROOT=$TMPROOT"\n'
    printf 'newdir > /dev/null\n'
    printf 'test_case "generated child"\n'
    case "$mode" in
      pass) printf 'assert_eq a a "a passing assertion"\nsummary\n' ;;
      fail) printf 'assert_eq a b "a deliberately failing assertion"\nsummary\n' ;;
      die)  printf 'printf "%%s\\n" "$deliberately_unset"\nsummary\n' ;;
      # Both arms of every assertion helper assert_eq does not already cover.
      # Written as a heredoc rather than the printf lines above because the body
      # is full of the quotes and dollars those would have to escape. The four
      # filesystem helpers need real state, and it is built under the child's own
      # newdir: anywhere else and the cleanup and no-writes cases in this same
      # file stop being true.
      helpers)
        cat <<'CHILD'
d="$(newdir)"
: > "$d/present"
printf 'x\n' > "$d/twin-a"
printf 'x\n' > "$d/twin-b"
printf 'y\n' > "$d/other"
assert_ne a b "assert_ne accepts two different values"
assert_ne a a "assert_ne rejects two equal values"
assert_contains abc b "assert_contains accepts a present substring"
assert_contains abc z "assert_contains rejects an absent substring"
assert_not_contains abc z "assert_not_contains accepts an absent substring"
assert_not_contains abc b "assert_not_contains rejects a present substring"
assert_file "$d/present" "assert_file accepts a file that is there"
assert_file "$d/absent" "assert_file rejects a file that is not"
assert_no_file "$d/absent" "assert_no_file accepts an absent path"
assert_no_file "$d/present" "assert_no_file rejects a present path"
assert_no_dir "$d/absent" "assert_no_dir accepts an absent directory"
assert_no_dir "$d" "assert_no_dir rejects a present directory"
assert_same "$d/twin-a" "$d/twin-b" "assert_same accepts two identical files"
assert_same "$d/twin-a" "$d/other" "assert_same rejects two different files"
summary
CHILD
        ;;
    esac
  } > "$f"
  chmod +x "$f"
  printf '%s\n' "$f"
}

# run_child <mode> [KEEP] — run it and set CHILD_ROOT. SIFT_TEST_KEEP is always
# set explicitly, empty by default: a developer running the whole suite with
# SIFT_TEST_KEEP=1 must not turn these cases green by inheritance.
run_child() {
  local child
  child="$(make_child "$1")"
  run_cmd "$TMPROOT" env SIFT_TEST_KEEP="${2:-}" "$child"
  CHILD_ROOT="$(printf '%s\n' "$R_OUT" | sed -n 's/^CHILD_TMPROOT=//p')"
}

test_case "a passing file takes its fixtures with it"
run_child pass
assert_eq 0 "$R_STATUS" "the child exits 0"
assert_ne "" "$CHILD_ROOT" "it announced a TMPROOT"
assert_no_dir "$CHILD_ROOT" "and nothing of it survives"

test_case "a failing file cleans up too"
# The path that matters: a suite that only tidied up when green would leak a
# tree on exactly the runs a developer repeats until it passes.
run_child fail
assert_eq 1 "$R_STATUS" "the child reports its failure"
assert_contains "$R_OUT" 'not ok' "with a failing assertion"
assert_no_dir "$CHILD_ROOT" "the temporary tree is still removed"

test_case "a file that dies before its summary cleans up as well"
run_child die
assert_ne 0 "$R_STATUS" "the child died"
assert_not_contains "$R_OUT" '# SUMMARY' "before reporting anything"
assert_no_dir "$CHILD_ROOT" "and the EXIT trap still ran"

test_case "SIFT_TEST_KEEP is the only way a tree survives, and it says so"
run_child pass 1
assert_eq 0 "$R_STATUS" "the child exits 0"
assert_contains "$R_OUT" "# kept fixtures under $CHILD_ROOT" "the path is printed to be inspected"
if [ -d "$CHILD_ROOT" ]; then t_ok "the tree is still there"
else t_fail "the tree is still there" "missing: $CHILD_ROOT"; fi
rm -rf "$CHILD_ROOT"

test_case "the temporary trees are outside the repository"
run_child pass 1
case "$CHILD_ROOT" in
  "$REPO_ROOT"/*) t_fail "fixtures live outside the working tree" "inside: $CHILD_ROOT" ;;
  *) t_ok "fixtures live outside the working tree, so a leak cannot be committed" ;;
esac
rm -rf "$CHILD_ROOT"

# --- Every assertion helper reports on both of its arms -----------------------

# child_verdict <message> — 'ok', 'not ok' or 'missing' for the child assertion
# carrying that message. Matched by message text and never by assertion number:
# every number below an added helper shifts the day an eighth one arrives, and a
# case that has to be renumbered to stay green is a case nobody re-reads.
child_verdict() {
  local line
  line="$(printf '%s\n' "$R_OUT" | grep -F "generated child: $1" | head -n 1)"
  case "$line" in
    'not ok '*) printf 'not ok\n' ;;
    'ok '*)     printf 'ok\n' ;;
    *)          printf 'missing\n' ;;
  esac
}

# One entry per call the `helpers` child makes, in the order it makes them.
HELPER_PASSES=(
  'assert_ne accepts two different values'
  'assert_contains accepts a present substring'
  'assert_not_contains accepts an absent substring'
  'assert_file accepts a file that is there'
  'assert_no_file accepts an absent path'
  'assert_no_dir accepts an absent directory'
  'assert_same accepts two identical files'
)
HELPER_FAILURES=(
  'assert_ne rejects two equal values'
  'assert_contains rejects an absent substring'
  'assert_not_contains rejects a present substring'
  'assert_file rejects a file that is not'
  'assert_no_file rejects a present path'
  'assert_no_dir rejects a present directory'
  'assert_same rejects two different files'
)

test_case "every assertion helper reports on both of its arms"
# The cases above read their verdict from assert_eq alone, so the failing arm of
# the other seven helpers was asserted nowhere: a helper whose t_fail arm had
# been broken — a mangled case pattern, an inverted [ -f ], a cmp that lost its
# -s — would print `ok` for a false claim, and every product failure it guards
# would come back green. Both arms are driven, because a helper wired to always
# fail is as wrong as one wired to always pass.
run_child helpers
assert_eq 1 "$R_STATUS" "the child reports its failures instead of dying"
for m in "${HELPER_PASSES[@]}"; do
  assert_eq 'ok' "$(child_verdict "$m")" "$m"
done
for m in "${HELPER_FAILURES[@]}"; do
  assert_eq 'not ok' "$(child_verdict "$m")" "$m"
done
assert_contains "$R_OUT" '# SUMMARY tests=1 assertions=14 failures=7 skipped=0' \
  "and each helper bumped T_ASSERTS once, T_FAILS once per false claim"
assert_no_dir "$CHILD_ROOT" "the state the filesystem helpers needed went with it"

# --- run.sh's own flags -------------------------------------------------------

# run_sh_fixture <mode> — a directory holding a byte-for-byte copy of the
# shipped run.sh and a `fixture` group with one generated child in it.
#
# run.sh resolves each group as a directory under its own dirname and rejects
# anything else, so the shipped copy cannot be pointed at a fixture group where
# it stands; and creating one inside tests/ would break the no-writes promise
# below. A copy of the real file is the way out — never a second implementation
# of it, which would pass whatever this file believed run.sh does.
run_sh_fixture() {  # run_sh_fixture <pass|fail|die|helpers>
  local d child
  d="$(newdir)"
  cp "$SUITE/run.sh" "$d/run.sh"
  chmod +x "$d/run.sh"
  mkdir -p "$d/fixture"
  child="$(make_child "$1")"
  cp "$child" "$d/fixture/generated.test.sh"
  chmod +x "$d/fixture/generated.test.sh"
  printf '%s\n' "$d"
}

test_case "SIFT_TEST_VERBOSE streams every assertion, not just the failures"
# The flag is documented in tests/README.md and in run.sh's own usage block and
# implemented in one line of run.sh, so it is the one promise here that has to be
# driven through run.sh rather than the harness.
#
# The boundary is deliberate and not widened here: that line sits in the PASS
# branch, so a *failing* file's passing assertions stay filtered by the
# `grep -v '^ok '` in the FAIL branch even under the flag. Whether the FAIL
# branch should stream too is a product change and belongs to its own ticket.
rundir="$(run_sh_fixture pass)"
run_cmd "$rundir" env SIFT_TEST_KEEP= "$rundir/run.sh" fixture
quiet_status="$R_STATUS"; quiet="$R_OUT"
run_cmd "$rundir" env SIFT_TEST_KEEP= SIFT_TEST_VERBOSE=1 "$rundir/run.sh" fixture
assert_eq 0 "$quiet_status" "the plain run is green"
assert_eq 0 "$R_STATUS" "and the verbose run agrees, exit status for exit status"
assert_contains "$quiet" 'PASS  fixture/generated.test.sh' "the plain run reports the file as passing"
assert_not_contains "$quiet" 'ok 1 - generated child: a passing assertion' \
  "and keeps the child's own assertion lines out of the output"
assert_contains "$R_OUT" 'PASS  fixture/generated.test.sh' "the verbose run prints the same PASS line"
assert_contains "$R_OUT" 'ok 1 - generated child: a passing assertion' \
  "and streams the assertion the plain run swallowed"
assert_contains "$quiet" '1 tests, 1 assertions, 0 failures, 0 skipped' "the plain run's counts"
assert_contains "$R_OUT" '1 tests, 1 assertions, 0 failures, 0 skipped' "are what the verbose run counts too"

# --- Nothing is written inside the repository --------------------------------

# repo_digest — every regular file under REPO_ROOT except DIGEST_EXCLUDE, with
# its size and checksum. The whole working tree and not an allowlist of
# subdirectories: a stray file at the repository root, or an edit to README.md —
# the very file cookbook/ extracts its recipes from — used to pass this case
# untouched.
#
# It inherits tree_digest's limit, which is worth knowing rather than fixing
# here: `find -type f` never yields a directory (tests/lib/harness.sh:102), so a
# suite that left an *empty* directory behind still passes. Widening the helper
# is its own change; a case that can create one asserts assert_no_dir itself.
repo_digest() {
  local p prune=()
  for p in $DIGEST_EXCLUDE; do prune+=(-path "$REPO_ROOT/$p" -prune -o); done
  find "$REPO_ROOT" "${prune[@]}" -type f -print | LC_ALL=C sort | while read -r f; do
    printf '%s ' "${f#"$REPO_ROOT/"}"
    wc -c < "$f" | tr -d ' \n'
    printf ' '
    cksum < "$f" | awk '{ print $1 }'
  done
}

test_case "the whole suite writes nothing in the repository"
# Measured around every file rather than around the heaviest writer: the promise
# tests/README.md makes is on behalf of the suite, and watching one file only
# ever catches that file. This one exclusion is not optional — suite-contract is
# itself a static/ file, so a sweep that included it would re-enter this case
# without bound. The files are driven directly rather than through run.sh, with
# SIFT_TEST_KEEP= and a TMPDIR outside the tree, so nothing here depends on the
# aggregator this suite also tests.
digest_before="$(mktemp "$TMPROOT/digest-before.XXXXXX")"
digest_after="$(mktemp "$TMPROOT/digest-after.XXXXXX")"
repo_digest > "$digest_before"
sweep_failed=''
for f in "$SUITE"/*/*.test.sh; do
  case "$f" in "$SUITE/static/suite-contract.test.sh") continue ;; esac
  run_cmd "$TMPROOT" env SIFT_TEST_KEEP= TMPDIR="$TMPROOT" "$f"
  [ "$R_STATUS" -eq 0 ] || sweep_failed="$sweep_failed ${f#"$SUITE/"}"
done
repo_digest > "$digest_after"
assert_eq "" "$sweep_failed" "every file in the sweep is green"
# The price of measuring the whole suite at once is that a failure names no
# single culprit, so assert_same's detail — the diff of the two digests — is the
# only thing that tells the operator what moved.
assert_same "$digest_before" "$digest_after" "the working tree is byte-identical afterwards"

# --- Determinism -------------------------------------------------------------

test_case "the same file run twice says exactly the same thing"
# Nothing in the suite may depend on a clock, a random name that reaches an
# assertion message, or the order a filesystem happens to hand back names.
run_cmd "$TMPROOT" env SIFT_TEST_KEEP= "$SUITE/scripts/sift-init-milestone.test.sh"
first="$R_OUT"
run_cmd "$TMPROOT" env SIFT_TEST_KEEP= "$SUITE/scripts/sift-init-milestone.test.sh"
assert_eq 0 "$R_STATUS" "both runs are green"
assert_eq "$first" "$R_OUT" "and byte-identical, assertion for assertion"

# --- No installable dependency -----------------------------------------------

# baseline_path — a directory of symlinks to BASELINE and nothing else.
baseline_path() {
  local bin t resolved missing=''
  bin="$TMPROOT/baseline-bin"
  [ -d "$bin" ] && { printf '%s\n' "$bin"; return 0; }
  mkdir -p "$bin"
  for t in $BASELINE; do
    resolved="$(command -v "$t" 2>/dev/null)" || { missing="$missing $t"; continue; }
    case "$resolved" in
      # A name that does not resolve to a path is a shell builtin — printf and
      # test are builtins in every shell that runs this suite, so there is
      # nothing to link and nothing missing. Linking the bare name would build a
      # symlink pointing at itself, and the farm would look complete while the
      # tool was unreachable.
      /*) ln -sf "$resolved" "$bin/$t" ;;
      ?*) ;;
      *) missing="$missing $t" ;;
    esac
  done
  BASELINE_MISSING="$missing"
  printf '%s\n' "$bin"
}

BIN="$(baseline_path)"

test_case "the baseline itself is present, and reachable through the farm"
assert_eq "" "${BASELINE_MISSING:-}" "every utility the suite is allowed to use resolves"
# The positive control for the two cases below: if a symlink in the farm were
# dangling, the restricted-PATH runs would fail for a reason that has nothing to
# do with the suite's dependencies.
run_cmd "$TMPROOT" env -i PATH="$BIN" bash -c \
  'for t in '"$(printf '%s ' $BASELINE)"'; do command -v "$t" > /dev/null || echo "$t"; done'
assert_eq "" "$R_OUT" "and is reachable with PATH pointing at the farm alone"
assert_no_file "$BIN/jq" "the farm holds nothing that is not on the list"
assert_no_file "$BIN/gawk" "no gawk"
assert_no_file "$BIN/dash" "no dash"
assert_no_file "$BIN/xmllint" "no xmllint"

test_case "the whole documented workflow runs with nothing but the baseline"
# gate -> init -> allocate -> create -> archive -> roadmap-check, with PATH
# holding only POSIX utilities and bash. This is the promise the convention
# makes to a consuming repository, so the suite has to be able to keep it too.
run_cmd "$TMPROOT" env -i PATH="$BIN" HOME="$TMPROOT" SIFT_TEST_KEEP= \
  TMPDIR="$TMPROOT" "$SUITE/e2e/lifecycle.test.sh"
assert_eq 0 "$R_STATUS" "the end-to-end lifecycle is green"
assert_contains "$R_OUT" 'failures=0' "with no failing assertion"
assert_eq "" "$R_ERR" "and nothing complaining on stderr"

test_case "an absent optional tool costs a matrix axis, never a failure"
# The portability matrix sweeps dash and three awks. None of them is baseline,
# so on a machine without them the axis has to collapse rather than fail.
run_cmd "$TMPROOT" env -i PATH="$BIN" HOME="$TMPROOT" SIFT_TEST_KEEP= \
  TMPDIR="$TMPROOT" "$SUITE/cookbook/allocate-id.test.sh"
assert_eq 0 "$R_STATUS" "the matrix file is green with only bash and one awk"
assert_contains "$R_OUT" 'failures=0' "no assertion failed"

summary
