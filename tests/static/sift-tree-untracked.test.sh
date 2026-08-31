#!/usr/bin/env bash
# Static analysis: AGENTS.md's claim that one file under `.ai/sift` is tracked.
#
# "This repository's own sift tree is untracked" settles that sift state is a
# working-tree artifact and says what that looks like in the index: `git
# ls-files .ai/sift` returns `.ai/sift/.gitignore` and nothing else. The section
# also names the way to break it — `git add -f` on a path under `.ai/sift`
# overrides the tree-local `*` rule one file at a time — and that is precisely
# the failure nobody sees. A half-tracked tree does not look broken: the tracked
# file simply turns up as a modification in every unrelated commit, which reads
# as diff noise. Commit `eda5051` held that state for two months and took a
# ticket of its own (SFT-0082) to notice.
#
# So the claim is resolved against the index rather than left as prose.
#
# The comparison is an EQUALITY, not a containment. The failure being guarded is
# an EXTRA entry, so "the output mentions .gitignore" is green through every
# instance of the bug; only "the output is exactly this one path" is not. Both
# directions of drift are reported for the same reason — an entry that appeared
# (`+`) and the allowed one that vanished (`-`) are different accidents.
#
# The allowed path is EXTRACTED from the section, never restated here. The
# milestone this case belongs to is documented-claim-verification, and a
# constant copied out of a document is a claim about a claim: it stays green
# after the prose it mirrors has been reworded into something else. Extracted,
# a deliberate decision to track something new is one AGENTS.md edit that this
# case then follows, and an accidental one still fails.
#
# What is NOT extracted is the directory the claim is about. `.ai/sift` is
# asserted flat below, because an extraction that drifted onto some other
# paragraph's path would leave this file verifying a different tree while
# reporting on this one.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

AGENTS="$REPO_ROOT/AGENTS.md"
SELF="tests/static/$(basename "$0")"

# The heading whose prose is authoritative. Named in the section itself, so a
# human editing it knows this suite reads it.
SECTION="## This repository's own sift tree is untracked"

# section_body <agents-file> — the lines under SECTION, up to the next `##`.
section_body() {
  awk -v sec="$SECTION" '
    { line = $0; sub(/[[:space:]]+$/, "", line) }
    /^##[[:space:]]/ { insec = (line == sec); next }
    insec { print line }
  ' "$1"
}

# allowed_entry <agents-file> — the one path the section says is tracked: the
# first backtick-quoted token in it that names a `.gitignore` inside a
# directory. Empty when the section no longer states it in that form, which the
# first case below asserts against rather than comparing two empty sets.
allowed_entry() {
  section_body "$1" | awk '
    found { next }
    {
      n = split($0, cell, "`")
      for (i = 2; i <= n; i += 2) {
        if (cell[i] ~ /^[^[:space:]]+\/\.gitignore$/) { print cell[i]; found = 1; break }
      }
    }
  '
}

# index_drift <root> <allowed> — empty when the git index of the checkout at
# <root> holds exactly <allowed> under that path's directory; otherwise one
# `+ <path>` line per entry that is tracked and should not be, and one
# `- <path>` line if the allowed entry is not tracked at all.
#
# This is the comparison itself, factored out so the positive control runs the
# identical code against a deliberately damaged tree. A control that
# re-implements the comparison proves nothing about the one that guards the
# repository.
#
# `-z` rather than plain output: git C-quotes a path with unusual bytes, so an
# offending entry would otherwise be reported under a name that is not its own.
index_drift() {
  local root="$1" allowed="$2" scope
  scope="$(dirname "$allowed")"
  git -C "$root" ls-files -z -- "$scope" | tr '\0' '\n' | awk -v want="$allowed" '
    $0 == "" { next }
    { seen[$0] = 1; if ($0 != want) printf "+ %s\n", $0 }
    END { if (!(want in seen)) printf "- %s\n", want }
  '
}

# git_gap <root> — empty when <root> can be asked this question, otherwise the
# reason it cannot, for `skip` to print.
#
# The convention forbids requiring an installable binary and the suite has to
# stay runnable from an exported tarball, so both "no git" and "not a checkout"
# are named gaps rather than failures — and neither may pass vacuously, which is
# what an unguarded `git ls-files` would do: it prints nothing outside a
# repository, and nothing is exactly what a clean tree prints.
#
# The toplevel is compared rather than `rev-parse --git-dir` merely succeeding,
# because git searches upward: a tarball unpacked inside some other checkout
# answers about that checkout, and an empty answer from it would be read here as
# this repository being clean.
git_gap() {
  local root="$1" top
  if ! command -v git > /dev/null 2>&1; then
    printf 'git is not installed\n'
    return 0
  fi
  if ! top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'the repository root is not a git checkout\n'
    return 0
  fi
  top="$(cd "$top" && pwd -P)"
  [ "$top" = "$root" ] || printf 'the repository root sits inside a checkout rooted at %s\n' "$top"
}

BODY="$(section_body "$AGENTS")"
ALLOWED="$(allowed_entry "$AGENTS")"
SCOPE="$(dirname "$ALLOWED")"
GAP="$(git_gap "$REPO_ROOT")"

test_case "AGENTS.md still states the claim this case reads"
assert_file "$AGENTS" "the repository's agent instructions are where the suite says"
assert_ne "" "$BODY" "the section is still in the document under that heading"
assert_ne "" "$ALLOWED" "the one tracked path was extracted from it"
assert_contains "$BODY" 'git ls-files' "the section states the claim as an ls-files result"
assert_contains "$BODY" 'git add -f' "and still names the force-add that breaks it"
if printf '%s\n' "$BODY" | grep -Fq -e "$SELF"; then
  t_ok "the section says which test file resolves it"
else
  t_fail "the section says which test file resolves it" "the section never names $SELF"
fi
# The one restatement, and the reason it is here rather than derived: this file
# is named for `.ai/sift`, and an extraction that wandered onto another
# paragraph would keep passing while verifying some unrelated directory.
assert_eq '.ai/sift' "$SCOPE" "the extracted path is the sift tree's own .gitignore"

test_case "exactly one file under the sift tree is tracked"
if [ -n "$GAP" ]; then
  skip "the index of this repository" "$GAP"
else
  drift="$(index_drift "$REPO_ROOT" "$ALLOWED")"
  if [ -z "$drift" ]; then
    t_ok "git ls-files $SCOPE is exactly $ALLOWED"
  else
    t_fail "git ls-files $SCOPE is exactly $ALLOWED" \
      "+ tracked and should not be, - allowed and missing:" "$drift"
  fi
fi

test_case "the same comparison catches a force-added file"
# The positive control. A guard that only ever runs against a tree that already
# passes is not proven, so the skeleton is copied into a throwaway repository —
# never this one, where a force-add is the damage being described — the trap
# AGENTS.md names is sprung inside it, and the identical function is asked.
if [ -n "$GAP" ]; then
  skip "the positive control for the index comparison" "$GAP"
else
  fake="$(newdir)/tree"
  mkdir -p "$fake/$SCOPE"
  cp "$REPO_ROOT/$ALLOWED" "$fake/$ALLOWED"
  git -C "$fake" init -q > /dev/null 2>&1
  # No commit and no identity: `git ls-files` reads the index, which `git add`
  # is enough to populate.
  git -C "$fake" add "$SCOPE" > /dev/null 2>&1
  assert_eq "" "$(index_drift "$fake" "$ALLOWED")" \
    "the untouched skeleton tracks exactly what the real tree does"

  victim="$SCOPE/MILESTONES.md"
  printf '# Milestones\n' > "$fake/$victim"
  # Proof the trap is the one AGENTS.md names: a plain add is refused by the
  # tree-local ignore rule, and only `-f` gets past it.
  git -C "$fake" add "$victim" > /dev/null 2>&1
  assert_eq "" "$(index_drift "$fake" "$ALLOWED")" \
    "an ordinary add cannot reach a path under $SCOPE"
  git -C "$fake" add -f "$victim" > /dev/null 2>&1
  assert_eq "+ $victim" "$(index_drift "$fake" "$ALLOWED")" \
    "the comparison names exactly the force-added file"

  # The other direction: the allowed entry itself going missing is drift too,
  # and a comparison written as "no extras" alone would call it clean.
  bare="$(newdir)/bare"
  mkdir -p "$bare/$SCOPE"
  git -C "$bare" init -q > /dev/null 2>&1
  assert_eq "- $ALLOWED" "$(index_drift "$bare" "$ALLOWED")" \
    "an empty index is reported as the allowed entry missing"
fi

summary
