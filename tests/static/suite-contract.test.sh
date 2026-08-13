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
. "$DIR/../lib/fixtures.sh"

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
# three.
#   .git                   git rewrites its own index, logs and packs for
#                          reasons that have nothing to do with the suite, and a
#                          cksum over the object store would cost more than the
#                          rest of this file put together.
#   .ai/kenkeep/_sessions  written by session-capture hooks that run outside the
#                          suite entirely, so a live agent session would turn the
#                          case red for something the suite did not do.
#   .ai/kenkeep/.state     lint, usage and bootstrap state, rewritten by the same
#                          class of hook and on the same terms (SFT-0060): a run
#                          launched from an agent session failed on
#                          .ai/kenkeep/.state/lint-state.json and passed again on
#                          a quiet tree, which blames the suite for a checksum it
#                          never touched.
# The sibling .ai/kenkeep/nodes is deliberately absent: node files are repository
# content, and a suite that rewrote one is exactly what the digest is for. The
# case after it pins that distinction.
DIGEST_EXCLUDE='.git
.ai/kenkeep/_sessions
.ai/kenkeep/.state'

# --- Fixture cleanup ---------------------------------------------------------

# make_child <pass|fail|skip|fail-skip|die|helpers|silent> — a minimal test file that announces
# its TMPROOT. One generator, one mode per shape of child: a second generator
# would be a second thing to keep in step with the harness.
make_child() {
  local mode="$1" f
  f="$(mktemp "$TMPROOT/child-$mode.XXXXXX")"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -u\n'
    # Every mode but `silent` gets the harness and a case to run in it. That one
    # sources nothing on purpose: what it stands for is a file that exits 0
    # having printed no summary at all — truncated, returned early, or dead
    # before it reached `summary` — and a child that sourced the harness could
    # not be that file, since the harness announces a TMPROOT on the way in
    # (SFT-0045). It has no fixture for the same reason: there is nothing to
    # leak, and the cleanup cases above are not what it is for.
    [ "$mode" = silent ] || {
      printf '. "%s/lib/harness.sh"\n' "$SUITE"
      printf 'echo "CHILD_TMPROOT=$TMPROOT"\n'
      printf 'newdir > /dev/null\n'
      printf 'test_case "generated child"\n'
    }
    case "$mode" in
      silent) printf 'exit 0\n' ;;
      pass) printf 'assert_eq a a "a passing assertion"\nsummary\n' ;;
      fail) printf 'assert_eq a b "a deliberately failing assertion"\nsummary\n' ;;
      skip) printf 'skip "a declared gap" "generated skip reason"\nsummary\n' ;;
      fail-skip) printf 'skip "a declared gap" "generated skip reason"\nassert_eq a b "a deliberately failing assertion"\nsummary\n' ;;
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

# --- The fixture library's own contract (SFT-0065) ---------------------------
#
# `tests/lib/fixtures.sh` is suite machinery in exactly the sense
# `tests/lib/harness.sh` is, so it belongs here beside the section above rather
# than in a `cookbook/` file. An assertion in `cookbook/` may only go red when a
# documented recipe is wrong — the group runs the fenced text extracted from
# README.md, it does not paraphrase it — and the three properties below were
# each asserted there against a fixture the recipe never touched, where they
# would have stayed green with the recipe deleted.
#
# Each one is load-bearing for a cookbook case that does run a recipe, which is
# why they are stated rather than dropped: the case that depends on it would
# quietly degenerate into a duplicate of its neighbour if a fixture change
# hollowed it out, with nothing going red.

test_case "the fixture's body shape is chosen explicitly, never derived from type: (SFT-0065)"
# The constraint the bug-backfill recipe's positive case depends on: it needs a
# ticket that IS `type: bug` and has NO `## Expected behaviour`, which a fixture
# deriving the body from the type could not build at all. Independence is
# asserted in both directions, because a coupling in either one breaks it.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0001 bare 'Bare bug')"
assert_eq 'bug' "$(fm "$f" type)" "the default fixture is a bug"
assert_eq "" "$(grep '^## Expected behaviour' "$f")" "…carrying no expected-behaviour section"
f="$(ticket "$d" open caching/docs SFT-0002 docsbug 'Docs with a bug body' \
      'type: docs' body=bug)"
assert_eq 'docs' "$(fm "$f" type)" "and the two are independent in the other direction too"
assert_ne "" "$(grep '^## Expected behaviour' "$f")" "…a docs ticket can carry a bug body"

test_case "the default fixture ticket carries no resolution: key (SFT-0065)"
# What makes the archive recipe's insert-arm case an insert-arm case rather than
# a second copy of its replace-arm neighbour. Neither arm's post-assertions can
# tell the two apart: a fixture that arrived carrying `resolution:` would still
# leave exactly one line reading `resolution: "Landed"` inside the fence,
# because the replace arm produces the same bytes.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 nores 'No resolution key')"
assert_eq 0 "$(grep -c '^resolution:' "$f")" "no resolution key anywhere in the default ticket"

test_case "an unrecognised key: value argument is written verbatim inside the fence (SFT-0065)"
# The pass-through rule tests/README.md documents, and the reason an optional
# key like `source:` can be set at all. `fm` stops at the closing marker, so a
# value it reads back is a value that landed inside the front-matter block
# rather than in the body.
d="$(newdir)"; make_tree "$d"
url='"https://example.invalid/owner/repo/issues/7"'
f="$(ticket "$d" open backlog/bug SFT-0042 sourced 'Sourced from a tracker' "source: $url")"
assert_eq "$url" "$(fm "$f" source)" "the unrecognised key reads back from inside the fence"
assert_eq 1 "$(grep -c '^source: ' "$f")" "written once, not appended beside a default"

# --- run.sh's own flags -------------------------------------------------------

# run_sh_fixture <mode> — a directory holding a byte-for-byte copy of the
# shipped run.sh and a `fixture` group with one generated child in it.
#
# run.sh resolves each group as a directory under its own dirname and rejects
# anything else, so the shipped copy cannot be pointed at a fixture group where
# it stands; and creating one inside tests/ would break the no-writes promise
# below. A copy of the real file is the way out — never a second implementation
# of it, which would pass whatever this file believed run.sh does.
run_sh_fixture() {  # run_sh_fixture <pass|fail|skip|fail-skip|die|helpers>
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

test_case "plain PASS and FAIL reports name every skip and its reason (SFT-0057)"
# This is the ticket's requested pin: run the shipped aggregator over generated
# children, without SIFT_TEST_VERBOSE, once through each reporting branch. The
# same skip line must be visible exactly once in both, and the run-wide summary
# must retain the reason while the assertion/skip counts stay the harness's.
for mode in skip fail-skip; do
  rundir="$(run_sh_fixture "$mode")"
  run_cmd "$rundir" env -i PATH="$PATH" HOME="$TMPROOT" "$rundir/run.sh" fixture
  case "$mode" in
    skip)
      assert_eq 0 "$R_STATUS" "the passing skip fixture keeps the run green"
      assert_contains "$R_OUT" 'PASS  fixture/generated.test.sh' "the skip is attached to a PASS file"
      assert_contains "$R_OUT" '1 tests, 1 assertions, 0 failures, 1 skipped' \
        "and reporting it did not change the child's counts"
      ;;
    fail-skip)
      assert_eq 1 "$R_STATUS" "the failing skip fixture keeps the run red"
      assert_contains "$R_OUT" 'FAIL  fixture/generated.test.sh' "the skip is attached to a FAIL file"
      assert_contains "$R_OUT" '1 tests, 2 assertions, 1 failures, 1 skipped' \
        "and reporting it did not change the child's counts"
      ;;
  esac
  assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -c '^      # SKIP a declared gap (generated skip reason)$')" \
    "$mode prints the named skip once without verbose output"
  assert_contains "$R_OUT" 'SKIP reasons: generated skip reason' \
    "$mode carries the distinct reason into TOTAL"
done

test_case "a file that printed no # SUMMARY line fails the run, and is named (SFT-0045)"
# An absent summary used to be read through the same `: "${t:=0}"` defaults an
# empty one takes, so a file that exited 0 having run nothing was aggregated as a
# passing file with no cases and the run stayed green — the one failure mode a
# harness cannot report on its own behalf, since the file that would report it is
# the file that said nothing. `summary` is documented in tests/README.md as
# required and as the last call for exactly this reason, which makes the
# aggregation run.sh's promise rather than the harness's: driven through a cp of
# the shipped run.sh, over a child that sources nothing and exits 0.
rundir="$(run_sh_fixture silent)"
run_cmd "$rundir" env SIFT_TEST_KEEP= "$rundir/run.sh" fixture
assert_eq 1 "$R_STATUS" "the run exits non-zero"
assert_contains "$R_OUT" 'FAIL  fixture/generated.test.sh' "the silent file is reported as failing"
assert_not_contains "$R_OUT" 'PASS' "and nothing in that run is reported as passing"
assert_contains "$R_OUT" 'fixture/generated.test.sh printed no # SUMMARY line' \
  "with the cause named, since the dump under a silent file is empty"
assert_contains "$R_OUT" '0 tests, 0 assertions, 1 failures, 0 skipped' \
  "counted as one failure rather than as a file of zeros"
assert_contains "$R_OUT" 'FAILING FILES: fixture/generated.test.sh' "and listed by name at the end"

# --- Nothing is written inside the repository --------------------------------

test_case "tree_digest is stable until a file changes"
# Every no-writes assertion in the suite depends on this helper returning a
# meaningful value and moving when bytes move. Restore the fixture between
# mutations so each unequal arm stands on its own: in particular, an earlier
# size change must not make the same-size rewrite look covered without cksum.
digest_root="$(newdir)"
printf 'x\n' > "$digest_root/watched"
printf 'keep\n' > "$digest_root/removed"
tree_d0="$(tree_digest "$digest_root")"
assert_ne "" "$tree_d0" "a non-empty tree produces a non-empty digest"
assert_eq "$tree_d0" "$(tree_digest "$digest_root")" \
  "an unchanged tree produces the same digest"

printf 'appended\n' >> "$digest_root/watched"
assert_ne "$tree_d0" "$(tree_digest "$digest_root")" \
  "appending bytes moves the digest"
printf 'x\n' > "$digest_root/watched"

printf 'y\n' > "$digest_root/watched"
assert_ne "$tree_d0" "$(tree_digest "$digest_root")" \
  "a same-size rewrite moves the digest through its checksum"
printf 'x\n' > "$digest_root/watched"

printf 'added\n' > "$digest_root/added"
assert_ne "$tree_d0" "$(tree_digest "$digest_root")" \
  "adding a file moves the digest"
rm "$digest_root/added"

rm "$digest_root/removed"
assert_ne "$tree_d0" "$(tree_digest "$digest_root")" \
  "removing a file moves the digest"

# repo_digest [root] — every regular file under <root>, default REPO_ROOT, except
# DIGEST_EXCLUDE, with its size and checksum. The whole working tree and not an
# allowlist of subdirectories: a stray file at the repository root, or an edit to
# README.md — the very file cookbook/ extracts its recipes from — used to pass
# this case untouched.
#
# The root is an argument only so the exclusion list can be audited against a
# fixture tree below; every caller that measures the suite passes nothing.
#
# It inherits tree_digest's limit, which is worth knowing rather than fixing
# here: `find -type f` never yields a directory (tests/lib/harness.sh:102), so a
# suite that left an *empty* directory behind still passes. Widening the helper
# is its own change; a case that can create one asserts assert_no_dir itself.
repo_digest() {
  local root="${1:-$REPO_ROOT}" p prune=()
  for p in $DIGEST_EXCLUDE; do prune+=(-path "$root/$p" -prune -o); done
  find "$root" "${prune[@]}" -type f -print | LC_ALL=C sort | while read -r f; do
    printf '%s ' "${f#"$root/"}"
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

test_case "the exclusion list does not swallow .ai/kenkeep/nodes (SFT-0060)"
# Every entry in DIGEST_EXCLUDE narrows the case above, so the list is only
# honest while each path stays as small as its reason. `.ai/kenkeep/.state` and
# `.ai/kenkeep/nodes` are siblings, and only the first has a writer outside the
# suite: node files are repository content, and a suite that silently rewrote one
# is the failure the digest exists to catch. Spelled a shade too widely — a
# trailing component dropped, a `*` added — the exclusion would take the nodes
# with it and the case above would go green on the damage it is watching for.
#
# Driven against a fixture root rather than REPO_ROOT, because the assertion
# needs a damaged file to look at and damaging one in the working tree is the
# thing this whole file promises never happens. repo_digest takes the root as an
# argument for that and nothing else; the prune list it builds from
# DIGEST_EXCLUDE is the same code either way.
excl_root="$(newdir)"
mkdir -p "$excl_root/.git/objects" "$excl_root/.ai/kenkeep/_sessions" \
  "$excl_root/.ai/kenkeep/.state" "$excl_root/.ai/kenkeep/nodes"
printf 'pack\n' > "$excl_root/.git/objects/pack-0"
printf 'session\n' > "$excl_root/.ai/kenkeep/_sessions/capture.jsonl"
printf 'state\n' > "$excl_root/.ai/kenkeep/.state/lint-state.json"
printf 'node\n' > "$excl_root/.ai/kenkeep/nodes/convention.md"
excl_before="$(repo_digest "$excl_root")"
assert_not_contains "$excl_before" '.ai/kenkeep/.state/' \
  "the excluded state directory is not walked at all"
assert_contains "$excl_before" '.ai/kenkeep/nodes/convention.md' \
  "while the node file beside it is"
# All three exclusions move at once, the way a live session moves them.
printf 'pack rewritten\n' > "$excl_root/.git/objects/pack-0"
printf 'session appended\n' >> "$excl_root/.ai/kenkeep/_sessions/capture.jsonl"
printf 'state rewritten\n' > "$excl_root/.ai/kenkeep/.state/lint-state.json"
assert_eq "$excl_before" "$(repo_digest "$excl_root")" \
  "a hook rewriting any of the three leaves the digest unmoved"
printf 'damage\n' >> "$excl_root/.ai/kenkeep/nodes/convention.md"
assert_ne "$excl_before" "$(repo_digest "$excl_root")" \
  "and a damaged node file is still reported, so the narrowing did not over-reach"

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

# baseline_cases — the cases static/schemas.test.sh tags @BASELINE-CASE, one name
# per line. Extracted from its `test_case` lines rather than restated here: a
# list copied into this file would pin a copy of the contract and then drift from
# it, which is the failure the tag exists to prevent.
baseline_cases() {
  awk -v open="test_case \"" '
    index($0, "@BASELINE-CASE") == 0 { next }
    index($0, open) != 1 { next }
    {
      rest = substr($0, length(open) + 1)
      e = index(rest, "\"")
      if (e) print substr(rest, 1, e - 1)
    }
  ' "$SUITE/static/schemas.test.sh"
}

test_case "the schema checks that must not need xmllint really run without it"
# The gap SFT-0054 closed, made checkable. README's worked XSD draft and the
# render-mapping table beside it were asserted only inside schemas.test.sh's
# `command -v xmllint` arm, and the case above pins that the farm has no
# xmllint — so on the machine this suite simulates, the documented draft was
# validated by nothing and the same run was green. Running that file here proves
# the structural cases are outside the gate: move either back inside it and its
# `ok` lines stop appearing in this output.
#
# The ceiling, honestly: deleting a case's tag AND moving it inside the gate in
# the same edit withdraws both claims at once and passes. That is the standing
# limit of every marker-driven pin in this suite — the same one
# static/prompt-readme-sections.test.sh carries — and it is a deliberate edit to
# a line whose comment says what it is for, not drift.
CASES="$(baseline_cases)"
assert_ne "" "$CASES" "schemas.test.sh names at least one case that must survive the farm"
run_cmd "$TMPROOT" env -i PATH="$BIN" HOME="$TMPROOT" SIFT_TEST_KEEP= \
  TMPDIR="$TMPROOT" "$SUITE/static/schemas.test.sh"
assert_eq 0 "$R_STATUS" "the schema file is green with only bash and the POSIX utilities"
assert_contains "$R_OUT" 'failures=0' "no assertion failed"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  line="$(printf '%s\n' "$R_OUT" | grep -F -e "- $name:" | head -n 1)"
  case "$line" in
    'ok '*) t_ok "ran without xmllint: $name" ;;
    *) t_fail "ran without xmllint: $name" "no ok line for that case in the restricted run" ;;
  esac
done <<EOF
$CASES
EOF

test_case "an absent optional tool costs a matrix axis, never a failure"
# The portability matrix sweeps dash and three awks. None of them is baseline,
# so on a machine without them the axis has to collapse rather than fail.
run_cmd "$TMPROOT" env -i PATH="$BIN" HOME="$TMPROOT" SIFT_TEST_KEEP= \
  TMPDIR="$TMPROOT" "$SUITE/cookbook/allocate-id.test.sh"
assert_eq 0 "$R_STATUS" "the matrix file is green with only bash and one awk"
assert_contains "$R_OUT" 'failures=0' "no assertion failed"
assert_contains "$R_OUT" '# SUMMARY tests=16 assertions=30 failures=0 skipped=0' \
  "narrowing itself changes none of the restricted run's counts"
for record in \
  '# NARROWED shell dash — not installed' \
  '# NARROWED awk gawk — not installed' \
  '# NARROWED awk mawk — not installed' \
  '# NARROWED awk nawk — not installed'; do
  assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -Fxc "$record")" \
    "the restricted run names the dropped member once: $record"
done

test_case "a locale the machine lacks costs its leg, never a fake one (SFT-0046)"
# The same promise one axis over, and the axis where an absent member used to be
# indistinguishable from a present one: `command -v` answers for dash and the
# awks, but a missing locale is not a missing binary — libc falls back to C
# behind a setlocale warning and the leg runs anyway, labelled with a locale it
# never entered. Every collation assertion under that label was then asserting
# about C while reporting otherwise.
#
# The axis is poisoned with a name no machine carries, for the length of this
# case, and both sweeps are driven because `locale_available` guards both. The
# shell and awk axes are pinned to one member each so the labels below are the
# whole of what ran: `awk` rather than gawk/mawk/nawk because it is the baseline
# name, so this case cannot narrow to nothing on a machine with no optional awk.
saved_locales="$matrix_locales"; saved_shells="$matrix_shells"; saved_awks="$matrix_awks"
BOGUS_LOCALE='zz_ZZ.no-such-locale'
leg_dir="$(newdir)"
LEGS=''; LEG_ERR=''
leg() {
  LEGS="$LEGS $R_LABEL"
  run_recipe "$leg_dir" 'printf "%s\n" "a b"'
  LEG_ERR="$LEG_ERR$R_ERR"
}
matrix_locales="C $BOGUS_LOCALE"; matrix_shells='bash'; matrix_awks='awk'
narrowed_log="$leg_dir/narrowed.log"
for_matrix leg > "$narrowed_log"
for_shell_locale leg >> "$narrowed_log"
matrix_locales="$saved_locales"; matrix_shells="$saved_shells"; matrix_awks="$saved_awks"

assert_eq ' bash/awk/C bash/C' "$LEGS" \
  "the callback runs once per sweep for C and never for the locale the machine lacks"
assert_eq "# NARROWED locale $BOGUS_LOCALE — not available" "$(cat "$narrowed_log")" \
  "both entry points share one uncounted, once-per-file narrowing channel"
assert_eq "" "$LEG_ERR" "and no leg's stderr carries a setlocale warning"
# The positive control. Without it "no warning reached a leg" is satisfied just as
# well by a probe that never runs anything, and the skipped locale above would be
# proof of nothing: this is the output the axis produces when the guard is absent.
R_LOCALE="$BOGUS_LOCALE"
run_recipe "$leg_dir" 'printf "%s\n" "a b"'
R_LOCALE=C
assert_contains "$R_ERR" 'setlocale' \
  "a leg really entered on that name would have warned, which is what the guard prevents"

test_case "a reworded README anchor turns the file that reads it red (SFT-0052)"
# The other half of the extraction contract. Each owning file asserts that a
# reworded anchor extracts NOTHING; what nothing costs is asserted here, once,
# because it takes a whole repository to measure. lib/recipes.sh resolves
# REPO_ROOT from its own location, so a copy of the tree under TMPROOT is a tree
# whose README a case may reword — the one edit the digest above exists to
# forbid in the real one.
#
# One block stands for the seven: the run-log schema, whose owning file is the
# cheapest to run and whose non-empty assertion is the first thing it does. What
# is being pinned is not that block in particular but that an empty extraction is
# a red file rather than a comparison of two empty sets, which is the rule
# tests/README.md states for all of them.
child="$(newdir)"
cp -R "$REPO_ROOT/README.md" "$REPO_ROOT/schemas" "$REPO_ROOT/src" "$SUITE" "$child/"
run_cmd "$child" env SIFT_TEST_KEEP= TMPDIR="$TMPROOT" "$child/tests/scripts/drain-log.test.sh"
assert_eq 0 "$R_STATUS" "the relocated copy is green before the damage, so the copy itself is not the variable"
damaged="$(readme_reworded "$child" "$ANCHOR_RUNLOG")" || damaged=''
assert_eq "$child/README.md" "$damaged" "its README is the one the reworded copy replaces"
run_cmd "$child" env SIFT_TEST_KEEP= TMPDIR="$TMPROOT" "$child/tests/scripts/drain-log.test.sh"
assert_eq 1 "$R_STATUS" "the same file fails once its anchor no longer matches"
assert_contains "$R_OUT" 'not ok' "with a failing assertion"
assert_contains "$R_OUT" 'the run-log block is there to read' \
  "and it is the extraction that fails, named, rather than a comparison passing on two empty sets"

summary
