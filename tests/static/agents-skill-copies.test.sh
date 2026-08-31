#!/usr/bin/env bash
# Static analysis: the inventory of cross-skill copies AGENTS.md keeps.
#
# "Duplication between skills" is a decision record: two rules are written out
# once per skill because the skills install independently, and the record lists
# every copy so an agent asking "how many copies of this rule are there, and
# where" gets a correct answer. A stale entry answers worse than no entry at
# all, because it is believed — a reader who follows one lands somewhere
# unrelated and concludes the record is wrong about which copies exist.
#
# So the entries are pinned here. Each `@SKILL-COPY:` line in that section names
# a file and the verbatim construct that holds the rule inside it, and both have
# to still be true: the file exists, and some line of it that is not a comment
# still holds the construct. A copy renamed, deleted, or moved to the other skill
# fails this file rather than rotting quietly in a document nobody re-reads.
#
# The entries are EXTRACTED from AGENTS.md, never restated here. A list restated
# in a test is a third place to forget, which is the failure this file exists to
# prevent rather than to demonstrate.
#
# Comment lines are excluded on purpose. Both skills explain their copy at length
# in prose directly above it, and an entry satisfied by a sentence about a
# construct would survive the construct's deletion — the one drift that matters
# most.
#
# What this file deliberately does NOT pin is a line number: SFT-0043 took those
# out of the record, and the reasoning is in the section itself.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

AGENTS="$REPO_ROOT/AGENTS.md"

# The heading whose entries are authoritative, and the marker on each entry.
# Both are documented in the section itself, so a human editing it knows this
# suite reads those lines.
SECTION='## Duplication between skills'
MARKER='@SKILL-COPY:'

TAB="$(printf '\t')"

# skill_copies <agents-file> — one "<path><TAB><construct>" per entry, in the
# order the record lists them. Only inside the named section: a marker quoted
# elsewhere in the document is prose about the record, not part of it.
skill_copies() {
  awk -v tag="$MARKER" -v sec="$SECTION" '
    { line = $0; sub(/[[:space:]]+$/, "", line) }
    /^##[[:space:]]/ { insec = (line == sec); next }
    !insec { next }
    {
      sub(/^[[:space:]]+/, "", line)
      if (index(line, tag) != 1) next
      line = substr(line, length(tag) + 1)
      sub(/^[[:space:]]+/, "", line)
      path = line
      sub(/[[:space:]].*$/, "", path)
      anchor = substr(line, length(path) + 1)
      sub(/^[[:space:]]+/, "", anchor)
      if (path == "" || anchor == "") next
      printf "%s\t%s\n", path, anchor
    }
  ' "$1"
}

# code_of <file> — the file with comment-only lines (and the shebang) dropped.
code_of() {
  awk '{ line = $0; sub(/^[[:space:]]+/, "", line); if (line ~ /^#/) next; print }' "$1"
}

# unresolved <agents-file> <root> — one line per entry that no longer holds, with
# the reason. Empty output means every copy the record names is still there.
#
# This is the comparison itself, factored out so the negative cases below can run
# the identical code against deliberately damaged copies. A guard proven only on
# the tree that already passes is not proven at all.
unresolved() {
  local agents="$1" root="$2" path anchor
  skill_copies "$agents" | while IFS="$TAB" read -r path anchor; do
    if [ ! -f "$root/$path" ]; then
      printf '%s :: %s (no such file)\n' "$path" "$anchor"
    elif ! code_of "$root/$path" | grep -Fq -e "$anchor"; then
      printf '%s :: %s (construct not found)\n' "$path" "$anchor"
    fi
  done
}

ENTRIES="$(skill_copies "$AGENTS")"
COUNT="$(printf '%s' "$ENTRIES" | grep -c '' || [ $? -eq 1 ])"
: "${COUNT:=0}"

test_case "the record lists its copies in a form this suite can read"
# Non-emptiness is its own assertion, not an assumption the checks below make.
# A parse that silently yields nothing satisfies every "each copy is still
# there" check vacuously and reports agreement on a record that names nothing —
# the same shape as SFT-0010, where "nothing to compare" passed as "compared and
# equal" in the validation recipes.
assert_file "$AGENTS" "the repository's agent instructions are where the suite says"
assert_ne 0 "$COUNT" "at least one $MARKER entry was extracted"
# grep rather than assert_contains: a failure here would otherwise print the
# whole document as the haystack and bury every other finding in the run.
if grep -Fq -e "$MARKER" "$AGENTS"; then t_ok "the marker is present verbatim"
else t_fail "the marker is present verbatim" "no $MARKER line in AGENTS.md"; fi
SELF="tests/static/$(basename "$0")"
if grep -Fq -e "$SELF" "$AGENTS"; then t_ok "the record says which test file reads it"
else t_fail "the record says which test file reads it" "AGENTS.md never names $SELF"; fi

test_case "the inventory still covers both skills and both rules"
# A coverage floor, not a second copy of the list: these are the three files the
# two recorded rules live in, so a well-meaning trim of the inventory fails here
# rather than silently narrowing what the record claims to track.
PATHS="$(printf '%s\n' "$ENTRIES" | cut -f1 | LC_ALL=C sort -u)"
assert_contains "$PATHS" 'src/skills/sift-drain/scripts/lib.sh' "the drain's roadmap reader"
assert_contains "$PATHS" 'src/skills/sift-prime/scripts/reserve-ids.sh' "prime's allocator"
assert_contains "$PATHS" 'src/skills/sift-drain/scripts/drain-log.sh' "the drain's ID check"

test_case "every copy the record names is still where it says"
broken="$(unresolved "$AGENTS" "$REPO_ROOT")"
if [ -z "$broken" ]; then
  t_ok "all $COUNT recorded copies resolve"
else
  t_fail "all $COUNT recorded copies resolve" "stale entries:" "$broken"
fi

# The victim for both negative cases: the first entry the record lists.
VICTIM_PATH="$(printf '%s\n' "$ENTRIES" | head -n 1 | cut -f1)"
VICTIM_ANCHOR="$(printf '%s\n' "$ENTRIES" | head -n 1 | cut -f2)"

test_case "a construct that is gone fails the check"
# The positive control. Copy every cited file into a throwaway root, delete the
# construct one entry names, and run the identical comparison against that root.
work="$(newdir)"
assert_ne "" "$VICTIM_PATH" "there is an entry to damage"
printf '%s\n' "$PATHS" | while IFS= read -r p; do
  [ -n "$p" ] || continue
  mkdir -p "$work/$(dirname "$p")"
  cp "$REPO_ROOT/$p" "$work/$p"
done
assert_eq "" "$(unresolved "$AGENTS" "$work")" "the untouched copy resolves every entry"

# `want != ""` is not defensive noise: without it an empty anchor — the very
# state the non-empty assertions above exist to catch — matches every line and
# empties the file, turning a broken parse into a green guard.
awk -v want="$VICTIM_ANCHOR" '
  { if (want != "" && index($0, want)) next; print }
' "$work/$VICTIM_PATH" > "$work/$VICTIM_PATH.tmp" \
  && mv "$work/$VICTIM_PATH.tmp" "$work/$VICTIM_PATH"

# Prove the damage landed before asserting the guard saw it: a copy that was
# never actually edited would fail the comparison for no reason at all.
assert_not_contains "$(code_of "$work/$VICTIM_PATH")" "$VICTIM_ANCHOR" \
  "the construct is gone from the copied file"
assert_eq "$VICTIM_PATH :: $VICTIM_ANCHOR (construct not found)" \
  "$(unresolved "$AGENTS" "$work")" \
  "the comparison names exactly the deleted construct"

test_case "an entry naming a file that does not exist fails the check"
# The other half of the control: the record can rot by pointing at a file that
# was moved or deleted, which no amount of reading the surviving files reveals.
bogus="src/skills/sift-drain/scripts/no-such-file.sh"
assert_no_file "$REPO_ROOT/$bogus" "the bogus path really is absent from the tree"
damaged="$(newdir)/AGENTS.md"
awk -v tag="$MARKER" -v repl="$MARKER $bogus $VICTIM_ANCHOR" '
  !hit && index($0, tag) { print repl; hit = 1; next }
  { print }
' "$AGENTS" > "$damaged"
assert_eq "$bogus $VICTIM_ANCHOR" \
  "$(skill_copies "$damaged" | head -n 1 | tr "$TAB" ' ')" \
  "the damaged record cites the missing file"
assert_eq "$bogus :: $VICTIM_ANCHOR (no such file)" \
  "$(unresolved "$damaged" "$REPO_ROOT")" \
  "the comparison names exactly the missing file"

test_case "the uniqueness half of the obligation, and why it is not counted here"
# The record carries two standing obligations. "Every copy it names is still
# there" is the one asserted above. The other — "each skill holds exactly one
# copy of the rule" — is deliberately not asserted as a count over these
# entries, and the reason is not that the count is awkward.
#
# It is that the count would be green through the only violation this
# repository has ever had. The second copy inside sift-prime's retired roadmap
# writer was a PARAPHRASE, not a repetition: its append hop selected its cell on
# the bare pattern while the duplicate guard beside it went through cell_id
# (SFT-0031, folded back onto one cell_id by SFT-0038). Every construct the
# record named appeared exactly once for the whole life of that bug. A guard that
# cannot see the failure it is named after is worse than none, because it is
# believed.
#
# The exemption it would additionally need makes the same point from the other
# side: `[0-9]{4,}` occurs twice in reserve-ids.sh on purpose — once per bucket
# the high-water mark is read from — so the count would ship with a
# hand-maintained exception list, which is the stale-record failure this file
# exists to prevent rather than to reproduce.
#
# Where the obligation IS guarded is behaviour, because that is where a
# paraphrase shows: "every ID sift-prime allocates is one sift-drain will log
# (SFT-0042)" in tests/scripts/prime-backlog.test.sh measures the ID rule on the
# IDs the allocator really emits, and drain-log.sh's dispatch and return
# positions are held to one refusal set through the same check in
# tests/scripts/drain-log.test.sh.
skip "one-copy-per-skill as a textual count over the recorded constructs" \
  "blind to the paraphrase that was the real bug, and needs a [0-9]{4,} exemption"

summary
