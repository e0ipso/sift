#!/usr/bin/env bash
# harness.sh — assertions and disposable fixtures for the sift test suite.
#
# Sourced by every tests/**/*.test.sh file. Depends on nothing but the baseline
# Unix userland the convention already requires, because a test suite that needs
# an installed framework contradicts the thing it is testing.
#
# A test file prints one TAP-ish line per assertion and one machine-readable
# summary line that tests/run.sh aggregates:
#
#   # SUMMARY tests=<n> assertions=<n> failures=<n> skipped=<n>

set -u

T_TESTS=0
T_ASSERTS=0
T_FAILS=0
T_SKIPS=0
T_CURRENT='(no case)'

T_NAME="$(basename "${0%.test.sh}")"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/sift-test-$T_NAME.XXXXXX")"

t_cleanup() {
  [ -n "${SIFT_TEST_KEEP:-}" ] && { echo "# kept fixtures under $TMPROOT"; return 0; }
  # A case may have made a directory unwritable on purpose; restore before rm.
  chmod -R u+rwX "$TMPROOT" 2>/dev/null
  rm -rf "$TMPROOT"
}
trap t_cleanup EXIT

# --- Case + assertion bookkeeping -------------------------------------------

test_case() { T_TESTS=$((T_TESTS + 1)); T_CURRENT="$1"; }

t_ok()   { T_ASSERTS=$((T_ASSERTS + 1)); echo "ok $T_ASSERTS - $T_CURRENT: $1"; }
t_fail() {
  T_ASSERTS=$((T_ASSERTS + 1)); T_FAILS=$((T_FAILS + 1))
  echo "not ok $T_ASSERTS - $T_CURRENT: $1"
  shift
  for detail in "$@"; do printf '#   %s\n' "$detail"; done
}

# skip <behaviour> <reason> — a deliberately uncovered behaviour, one line each.
skip() {
  T_SKIPS=$((T_SKIPS + 1))
  echo "ok $((T_ASSERTS + 1)) - # SKIP $1 ($2)"
  T_ASSERTS=$((T_ASSERTS + 1))
}

assert_eq() {  # assert_eq <expected> <actual> <message>
  if [ "$1" = "$2" ]; then t_ok "$3"
  else t_fail "$3" "expected: [$1]" "actual:   [$2]"; fi
}

assert_ne() {  # assert_ne <unexpected> <actual> <message>
  if [ "$1" != "$2" ]; then t_ok "$3"
  else t_fail "$3" "did not expect: [$1]"; fi
}

assert_contains() {  # assert_contains <haystack> <needle> <message>
  case "$1" in
    *"$2"*) t_ok "$3" ;;
    *) t_fail "$3" "missing substring: [$2]" "in: [$1]" ;;
  esac
}

assert_not_contains() {  # assert_not_contains <haystack> <needle> <message>
  case "$1" in
    *"$2"*) t_fail "$3" "unexpected substring: [$2]" "in: [$1]" ;;
    *) t_ok "$3" ;;
  esac
}

assert_file() {  # assert_file <path> <message>
  if [ -f "$1" ]; then t_ok "$2"; else t_fail "$2" "no such file: $1"; fi
}

assert_no_file() {  # assert_no_file <path> <message>
  if [ -e "$1" ]; then t_fail "$2" "unexpectedly present: $1"; else t_ok "$2"; fi
}

assert_no_dir() {  # assert_no_dir <path> <message>
  if [ -d "$1" ]; then t_fail "$2" "unexpectedly present: $1"; else t_ok "$2"; fi
}

assert_same() {  # assert_same <fileA> <fileB> <message>
  if cmp -s "$1" "$2"; then t_ok "$3"
  else t_fail "$3" "differ: $1 vs $2" "$(diff "$1" "$2" 2>&1 | head -n 6)"; fi
}

# --- Disposable fixtures -----------------------------------------------------

# A fresh working directory for one case. Everything lives under TMPROOT and is
# removed on exit, including on failure.
newdir() {
  mktemp -d "$TMPROOT/case.XXXXXX"
}

# Checksum a whole tree so "untouched" can be asserted byte-for-byte.
tree_digest() {  # tree_digest <dir>
  find "$1" -type f | LC_ALL=C sort | while read -r f; do
    printf '%s ' "$f"
    wc -c < "$f" | tr -d ' \n'
    printf ' '
    cksum < "$f" | awk '{ print $1 }'
  done
}

# markers_above <dir> [marker…] — every project marker that exists on the walk
# from <dir> up to `/`, one `<ancestor>/<marker>` path per line, and nothing at
# all when the walk is clean (SFT-0079).
#
# This is a claim about TMPROOT, which this file creates above, so it lives in
# the harness rather than in fixtures.sh: no sift tree is involved, and a file
# sourcing only the harness must still be able to state its sandbox premise.
# Three files do — each keeps its own case and its own failure message, because
# what the walk reaching a real project would invalidate differs per file.
#
# The marker list is a parameter, defaulting to `.ai/sift`, so the site that
# needs a wider list (the gate's four tiers) names it where its tier semantics
# are already documented instead of forking this helper.
#
# The test is `-e`, never `-d`: a `.git` FILE is a legitimate marker at the wide
# site — it is what a worktree and a submodule root carry — so a `-d`-only walk
# would silently stop seeing them.
markers_above() {
  local d="$1"; shift
  [ "$#" -gt 0 ] || set -- .ai/sift
  local parent m
  while :; do
    for m in "$@"; do
      [ -e "$d/$m" ] && printf '%s\n' "$d/$m"
    done
    parent="$(dirname "$d")"
    [ "$parent" = "$d" ] && break
    d="$parent"
  done
}

# run_cmd <workdir> <command…> — run a shipped script through its real command
# line. Sets R_STATUS, R_OUT, R_ERR; honours R_LOCALE.
#
# Those three are the helper's return channel, not scratch: every reader is a
# test file that sources this library and then asserts on them. shellcheck sees
# one file at a time, so a cross-file read is invisible to it and all three
# assignments look like dead stores. `export` would not be the truthful fix —
# the readers are functions in this same shell, not child processes — so the
# finding is silenced at the one function that publishes them.
# shellcheck disable=SC2034
run_cmd() {
  local dir="$1"; shift
  local outf errf
  outf="$(mktemp "$TMPROOT/out.XXXXXX")"
  errf="$(mktemp "$TMPROOT/err.XXXXXX")"
  ( cd "$dir" && env LC_ALL="${R_LOCALE:-C}" "$@" ) > "$outf" 2> "$errf" < /dev/null
  R_STATUS=$?
  R_OUT="$(cat "$outf")"
  R_ERR="$(cat "$errf")"
}

# assert_marker_is_inert <label> <workdir> <command…> — the bare-versus-`--`
# equivalence, in one place (SFT-0076).
#
# SFT-0024 and SFT-0033 gave every card script one spelling of `--`, so several
# of them make the identical claim: a lone marker with nothing behind it is
# accepted and changes nothing. That claim used to be restated word for word per
# script, which reads as three permutations of one case rather than as one rule
# asked of three scripts. Each script still owns its own loop and its own `--)`
# arm, so each still gets its own three assertions — what is shared is the
# wording and the procedure, not the coverage.
#
# The command is passed whole rather than as a script path, because these scripts
# are driven through `env SIFT_ROOT=… <script>` and the marker has to be appended
# to a real command line for the parse to be the one under test.
assert_marker_is_inert() {
  local label="$1" dir="$2"; shift 2
  local status out err
  run_cmd "$dir" "$@"
  status="$R_STATUS"; out="$R_OUT"; err="$R_ERR"
  run_cmd "$dir" "$@" --
  assert_eq "$status" "$R_STATUS" "$label: the marker alone exits exactly as the bare run does"
  assert_eq "$out" "$R_OUT" "$label: and prints the same output, byte for byte"
  assert_eq "$err" "$R_ERR" "$label: with the same stderr"
}

summary() {
  echo "# SUMMARY tests=$T_TESTS assertions=$T_ASSERTS failures=$T_FAILS skipped=$T_SKIPS"
  [ "$T_FAILS" -eq 0 ]
}
