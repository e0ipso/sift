#!/usr/bin/env bash
# The suite's own promises, asserted rather than described (SFT-0008).
#
# tests/README.md makes three claims on behalf of every file here: the suite
# needs no installable dependency, it is deterministic, and every fixture lives
# under a temporary directory that is removed on exit — including on failure.
# They are the same claims the convention makes about its recipes, so they are
# held to the same bar: this file breaks them on purpose and checks the harness
# keeps them anyway.
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

# --- Fixture cleanup ---------------------------------------------------------

# make_child <pass|fail|die> — a minimal test file that announces its TMPROOT.
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

# --- Nothing is written inside the repository --------------------------------

repo_digest() {
  tree_digest "$REPO_ROOT/src"
  tree_digest "$REPO_ROOT/tests"
  [ -d "$REPO_ROOT/.ai/sift" ] && tree_digest "$REPO_ROOT/.ai/sift"
  tree_digest "$REPO_ROOT/schemas"
}

test_case "the heaviest writer in the suite writes nothing in the repository"
# sift-init.sh materialises whole trees and roadmap-check.sh resolves a root by
# walking upward, so if any file in the suite were going to write into
# .ai/sift or the shipped card, it would be this one.
before="$(repo_digest)"
run_cmd "$TMPROOT" env SIFT_TEST_KEEP= "$SUITE/scripts/sift-init-tree.test.sh"
assert_eq 0 "$R_STATUS" "the child run is green"
assert_eq "$before" "$(repo_digest)" \
  "src/, tests/, schemas/ and .ai/sift are byte-identical afterwards"

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
