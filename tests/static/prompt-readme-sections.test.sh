#!/usr/bin/env bash
# Static analysis: the bounded spec read the ticket-agent prompt promises.
#
# `references/ticket-agent-prompt.md` no longer tells a sub-agent to read the
# whole README. It names the sections instead, by exact heading text, and an
# agent that reads only those sections is an agent that can be starved by a
# rename it never sees: the spec would still be well-formed, the prompt would
# still look sensible, and rule 9 would simply stop being read.
#
# So the names are pinned here. Every `@README-SECTION:` line in the prompt must
# still name a live heading in BOTH copies of the spec — the normative
# `README.md` and the `sift-init` asset that ships into a consuming repository as
# `.ai/sift/README.md`, which is the copy the dispatched agent actually opens.
#
# The names are EXTRACTED from the prompt, never restated here. A list restated
# in a test pins a copy of the contract and then drifts from it, which is the
# failure this file exists to prevent rather than to demonstrate.
#
# Headings are matched outside fenced blocks only. The spec's body-template block
# spells `## Problem` and `## Direction` as sample content, and a section name
# that resolved against a sample rather than against a real heading would pass on
# a spec that had lost the section entirely.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

PROMPT="$REPO_ROOT/src/skills/sift-drain/references/ticket-agent-prompt.md"
DRAFTING_PROMPT="$REPO_ROOT/src/skills/sift-prime/references/drafting-agent-prompt.md"
SHIPPED="$REPO_ROOT/src/skills/sift-init/assets/README.md"

# The marker. It is documented in the prompt itself, under "The bounded spec
# read", so a human editing that file knows this suite reads these lines.
MARKER='@README-SECTION:'

# prompt_sections — one heading name per line, in the order the prompt names
# them. The tag may be indented, since the list lives inside the template's
# fenced block; everything after the tag and its blanks is the heading text.
prompt_sections() {
  awk -v tag="$MARKER" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, tag) != 1) next
      line = substr(line, length(tag) + 1)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "$PROMPT" "$DRAFTING_PROMPT" | sort -u
}

# headings_of <file> — every ATX heading line outside a fenced block, trimmed of
# trailing blanks so a heading is compared on the text and not on its whitespace.
headings_of() {
  awk '
    /^[[:space:]]*```/ { inb = !inb; next }
    inb { next }
    /^#/ { line = $0; sub(/[[:space:]]+$/, "", line); print line }
  ' "$1"
}

# missing_from <spec-file> — the named sections that spec no longer has, one per
# line. Empty output means the prompt and that copy of the spec agree.
#
# This is the comparison itself, factored out so the negative case below can run
# the identical code against a deliberately damaged copy. A guard proven only on
# the tree that already passes is not proven at all.
missing_from() {
  local spec="$1" heads name
  heads="$(headings_of "$spec")"
  prompt_sections | while IFS= read -r name; do
    printf '%s\n' "$heads" | grep -Fxq -e "$name" || printf '%s\n' "$name"
  done
}

SECTIONS="$(prompt_sections)"
COUNT="$(printf '%s' "$SECTIONS" | grep -c '' || [ $? -eq 1 ])"
: "${COUNT:=0}"

test_case "the prompt names its bounded read in a form this suite can read"
# Non-emptiness is its own assertion, not an assumption the loop below makes.
# A parse that silently yields nothing satisfies every "each name exists" check
# vacuously and reports agreement on a prompt that names nothing at all — the
# same shape as SFT-0010, where "nothing to compare" passed as "compared and
# equal" in the validation recipes.
assert_file "$PROMPT" "the canonical ticket-agent prompt is where the skill says"
assert_ne 0 "$COUNT" "at least one $MARKER line was extracted"
# grep rather than assert_contains: a failure here would otherwise print the
# whole prompt as the haystack and bury every other finding in the run.
if grep -Fq -e "$MARKER" "$PROMPT"; then t_ok "the marker is present verbatim"
else t_fail "the marker is present verbatim" "no $MARKER line in the prompt"; fi
SELF="tests/static/$(basename "$0")"
if grep -Fq -e "$SELF" "$PROMPT"; then t_ok "the prompt says which test file reads it"
else t_fail "the prompt says which test file reads it" "the prompt never names $SELF"; fi

test_case "every named section is a live heading in the normative spec"
missing="$(missing_from "$README")"
if [ -z "$missing" ]; then
  t_ok "all $COUNT named sections exist in README.md"
else
  t_fail "all $COUNT named sections exist in README.md" \
    "renamed or removed:" "$missing"
fi

test_case "every named section is a live heading in the spec that ships"
# The asset copy is the one a dispatched agent opens as .ai/sift/README.md, so a
# mirror that has drifted starves the agent even while README.md is intact.
missing="$(missing_from "$SHIPPED")"
if [ -z "$missing" ]; then
  t_ok "all $COUNT named sections exist in the sift-init asset"
else
  t_fail "all $COUNT named sections exist in the sift-init asset" \
    "renamed or removed:" "$missing"
fi

test_case "the named set covers rule 9, the front matter and the body"
# Three sections the prompt cannot drop without starving the agent of something
# the skill requires of it. Named positively so a well-meaning trim of the list
# fails here rather than silently narrowing what a sub-agent reads.
assert_contains "$SECTIONS" '## Rules for agents' "rule 9 lives here"
assert_contains "$SECTIONS" '## Front-matter schema' "the required keys live here"
assert_contains "$SECTIONS" '## Ticket body' "the canonical sections live here"

test_case "a renamed heading fails the comparison"
# The positive control. Copy the spec, rename one of the very headings the prompt
# names, and run the same comparison against the copy: a guard that only ever
# runs against a passing tree proves nothing about the failing one.
work="$(newdir)"
copy="$work/README.md"
cp "$README" "$copy"
victim="$(prompt_sections | head -n 1)"
assert_ne "" "$victim" "there is a section to damage"
assert_eq "" "$(missing_from "$copy")" "the untouched copy agrees with the prompt"

# `want != ""` is not defensive noise: without it an empty victim — the very
# state the non-empty assertion above exists to catch — matches every blank line
# and rewrites the whole spec, turning a broken parse into a green guard.
awk -v want="$victim" '
  {
    line = $0
    sub(/[[:space:]]+$/, "", line)
    if (want != "" && line == want) { print "## Renamed by the negative case"; next }
    print
  }
' "$copy" > "$copy.tmp" && mv "$copy.tmp" "$copy"

# Prove the damage landed before asserting that the guard saw it: a copy that
# was never actually edited would fail the comparison for no reason at all.
assert_not_contains "$(headings_of "$copy")" "$victim" "the heading is gone from the copy"
assert_eq "$victim" "$(missing_from "$copy")" \
  "the comparison names exactly the renamed section"

summary
