#!/usr/bin/env bash
# Static analysis: the claims a skill's prose makes about a shipped file.
#
# The skills restate things that live somewhere else — the `references/*.md`
# prompts they dispatch, the gate's state names, the XSD root element per ticket
# type, the convention's closed `type` set, README's body headings — and each
# skill's front-matter `name` restates the directory that holds it. A rename on
# the other side of any of those leaves the renamed thing correct and the skill
# confidently naming what is no longer there, which is worse than silence: the
# damage lands on a dispatched sub-agent, which has nothing to compare against
# either and will not report it.
#
# So the claims are tagged. Every `@PIN:` line in a skill document names a target
# and the verbatim construct that has to still be in it, and this file resolves
# each one against the repository root.
#
# The tags are EXTRACTED from the skills, never restated here. A list restated in
# a test is a third place to forget, which is the drift this file exists to
# prevent rather than to demonstrate. It is the same shape as
# `tests/static/prompt-readme-sections.test.sh` and
# `tests/static/agents-skill-copies.test.sh`, and it differs from both in three
# places that a verbatim copy of either would get wrong:
#
#   - The haystack is the RAW file. `agents-skill-copies` drops comment lines,
#     which is right for shell and fatal here: a markdown ATX heading is a line
#     whose first character is `#`, so a filtered haystack would look for
#     `## Problem` in a file it had just deleted every heading from.
#   - Fenced blocks are NOT excluded. `prompt-readme-sections` skips them because
#     it matches headings and the spec spells sample headings inside a fence; the
#     targets here are the opposite case — the closed `type` set sits inside
#     README's directory-layout block and the body headings inside a fenced
#     `markdown` block — so fixed-string containment against the whole file is
#     the right comparison.
#   - A target ending in `/` is a skill DIRECTORY, and its construct is resolved
#     against that directory's `SKILL.md` FRONT MATTER only. The `name`-vs-
#     directory claim is an equality between two values rather than "some other
#     file holds this string", and a whole-file match would be satisfied by the
#     marker line itself, since the marker spells the name too.
#
# What this file deliberately does NOT pin is a line number. SFT-0043 settled
# that for `@SKILL-COPY:` and the reasoning transfers unchanged: a construct that
# merely moves within its own file is drift this shape does not detect, and does
# not need to.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

# The marker. It is documented in every skill that carries it, beside the prose
# making the claim, so a human editing that prose knows this suite reads it.
MARKER='@PIN:'
SELF="tests/static/$(basename "$0")"
TAB="$(printf '\t')"

# skill_docs — every skill document that could carry a marker. Discovered rather
# than listed: a new skill, or a new reference file inside one, is in scope the
# moment it exists, and a list here would be one more place to forget.
skill_docs() {
  find "$REPO_ROOT/src/skills" -name '*.md' | LC_ALL=C sort
}

# skill_dirs — one repo-relative path per installable skill directory.
skill_dirs() {
  find "$REPO_ROOT/src/skills" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort \
    | while IFS= read -r d; do printf '%s\n' "${d#"$REPO_ROOT/"}"; done
}

# pins_of <file> — one "<target><TAB><construct>" per marker line, in the order
# the document writes them. The tag may be indented, since a marker inside a
# numbered list is indented with its item; everything up to the first blank after
# the tag is the target and the rest of the line is the construct. Trailing
# blanks are trimmed, so a construct cannot end in whitespace — no target in this
# repository does, and an editor that strips trailing blanks would otherwise
# break the pin rather than the claim.
pins_of() {
  awk -v tag="$MARKER" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (index(line, tag) != 1) next
      line = substr(line, length(tag) + 1)
      sub(/^[[:space:]]+/, "", line)
      target = line
      sub(/[[:space:]].*$/, "", target)
      construct = substr(line, length(target) + 1)
      sub(/^[[:space:]]+/, "", construct)
      if (target == "" || construct == "") next
      printf "%s\t%s\n", target, construct
    }
  ' "$1"
}

# all_pins — every marker in every skill document, deduplicated. Two skills pin the
# gate's state names identically on purpose, and one shared claim is one claim.
all_pins() {
  skill_docs | while IFS= read -r f; do pins_of "$f"; done | LC_ALL=C sort -u
}

# pinning_docs — the repo-relative documents that carry at least one marker.
pinning_docs() {
  skill_docs | while IFS= read -r f; do
    [ -n "$(pins_of "$f")" ] && printf '%s\n' "${f#"$REPO_ROOT/"}"
  done
}

# front_matter_of <skill-file> — the lines between the first `---` fence pair.
front_matter_of() {
  awk '
    NR == 1 && $0 == "---" { inb = 1; next }
    inb && $0 == "---" { exit }
    inb { print }
  ' "$1"
}

# unresolved <pins> <root> — one line per pin that no longer holds, with the
# reason. Empty output means every claim the skills make still resolves.
#
# This is the comparison itself, factored out so the negative cases below can run
# the identical code against deliberately damaged copies. A guard proven only on
# the tree that already passes is not proven at all.
unresolved() {
  local pins="$1" root="$2" target construct skill
  printf '%s\n' "$pins" | while IFS="$TAB" read -r target construct; do
    [ -n "$target" ] || continue
    case "$target" in
      */)
        skill="$root/${target%/}"
        if [ ! -d "$skill" ]; then
          printf '%s :: %s (no such directory)\n' "$target" "$construct"
        elif [ ! -f "$skill/SKILL.md" ]; then
          printf '%s :: %s (no SKILL.md)\n' "$target" "$construct"
        elif ! front_matter_of "$skill/SKILL.md" | grep -Fq -e "$construct"; then
          printf '%s :: %s (not in the front matter)\n' "$target" "$construct"
        fi
        ;;
      *)
        if [ ! -f "$root/$target" ]; then
          printf '%s :: %s (no such file)\n' "$target" "$construct"
        elif ! grep -Fq -e "$construct" "$root/$target"; then
          printf '%s :: %s (construct not found)\n' "$target" "$construct"
        fi
        ;;
    esac
  done
}

# mirror_targets <pins> <root> — copy every target a pin names into a throwaway
# root, so a negative case can damage one without touching the repository.
mirror_targets() {
  local pins="$1" root="$2" target
  printf '%s\n' "$pins" | cut -f1 | LC_ALL=C sort -u | while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      */) mkdir -p "$root/${target%/}"
          cp "$REPO_ROOT/${target}SKILL.md" "$root/${target}SKILL.md" ;;
      *)  mkdir -p "$root/$(dirname "$target")"
          cp "$REPO_ROOT/$target" "$root/$target" ;;
    esac
  done
}

PINS="$(all_pins)"
COUNT="$(printf '%s' "$PINS" | grep -c '' || [ $? -eq 1 ])"
: "${COUNT:=0}"
DOCS="$(pinning_docs)"

test_case "the skills tag their claims in a form this suite can read"
# Non-emptiness is its own assertion, not an assumption the checks below make.
# A parse that silently yields nothing satisfies every "the construct is still
# there" check vacuously and reports agreement on skills that pin nothing at all —
# the same shape as SFT-0010, where "nothing to compare" passed as "compared and
# equal" in the validation recipes.
assert_ne "" "$DOCS" "at least one skill document carries the marker"
assert_ne 0 "$COUNT" "at least one $MARKER line was extracted"
unnamed="$(printf '%s\n' "$DOCS" | while IFS= read -r d; do
  [ -n "$d" ] || continue
  grep -Fq -e "$SELF" "$REPO_ROOT/$d" || printf '%s\n' "$d"
done)"
if [ -z "$unnamed" ]; then
  t_ok "every pinning document names the test file that reads it"
else
  t_fail "every pinning document names the test file that reads it" \
    "these never name $SELF:" "$unnamed"
fi

test_case "every claim the skills pin still holds in the file it names"
broken="$(unresolved "$PINS" "$REPO_ROOT")"
if [ -z "$broken" ]; then
  t_ok "all $COUNT pinned claims resolve"
else
  t_fail "all $COUNT pinned claims resolve" "stale claims:" "$broken"
fi

test_case "every skill pins its own installable identity"
# The one claim every skill makes, including `sift-init`, which ships no
# references and dispatches no prompts. Asserted per skill directory found on
# disk rather than per name written here, so a skill whose marker was dropped
# fails instead of silently narrowing the check.
DIR_TARGETS="$(printf '%s\n' "$PINS" | cut -f1 | grep '/$' || [ $? -eq 1 ])"
skills="$(skill_dirs)"
assert_ne "" "$skills" "there are skill directories to check"
missing="$(printf '%s\n' "$skills" | while IFS= read -r c; do
  [ -n "$c" ] || continue
  printf '%s\n' "$DIR_TARGETS" | grep -Fxq -e "$c/" || printf '%s\n' "$c"
done)"
assert_eq "" "$missing" "every skill directory is the target of a directory pin"

test_case "a directory target reads the front matter, not the body"
# The rule that stops a `name:` marker matching itself. Copy one skill, move its
# `name:` line out of the front matter and into the body — the string is still
# in the file, character for character — and the pin must still fail.
work="$(newdir)"
DIRPIN="$(printf '%s\n' "$PINS" | grep -F -e "/$TAB" | head -n 1)"
assert_ne "" "$DIRPIN" "there is a directory pin to exercise"
mirror_targets "$DIRPIN" "$work"
assert_eq "" "$(unresolved "$DIRPIN" "$work")" "the untouched copy resolves it"

victim_dir="$(printf '%s\n' "$DIRPIN" | cut -f1)"
victim_name="$(printf '%s\n' "$DIRPIN" | cut -f2)"
skill="$work/${victim_dir}SKILL.md"
awk -v want="$victim_name" '
  BEGIN { fm = 0 }
  NR == 1 && $0 == "---" { fm = 1; print; next }
  fm == 1 && $0 == "---" { fm = 2; print; next }
  fm == 1 && want != "" && $0 == want { moved = want; next }
  { print }
  END { if (moved != "") printf "\n%s\n", moved }
' "$skill" > "$skill.tmp" && mv "$skill.tmp" "$skill"

assert_contains "$(cat "$skill")" "$victim_name" "the string is still in the file"
assert_not_contains "$(front_matter_of "$skill")" "$victim_name" \
  "but no longer in the front matter"
assert_eq "$victim_dir :: $victim_name (not in the front matter)" \
  "$(unresolved "$DIRPIN" "$work")" \
  "the comparison names exactly the skill whose key moved"

test_case "a skill directory renamed without its name key fails"
# The other half of the same equality: the key is intact, the directory it has
# to agree with is not.
work="$(newdir)"
mirror_targets "$DIRPIN" "$work"
assert_eq "" "$(unresolved "$DIRPIN" "$work")" "the untouched copy resolves it"
mv "$work/${victim_dir%/}" "$work/${victim_dir%/}-renamed"
assert_eq "$victim_dir :: $victim_name (no such directory)" \
  "$(unresolved "$DIRPIN" "$work")" \
  "the comparison names exactly the skill that moved"

test_case "a construct that is gone fails the check"
# The first negative control. Mirror every target into a throwaway root, delete
# the construct one pin names, and run the identical comparison against it.
work="$(newdir)"
mirror_targets "$PINS" "$work"
assert_eq "" "$(unresolved "$PINS" "$work")" "the untouched mirror resolves every pin"

VICTIM="$(printf '%s\n' "$PINS" | grep -Fv -e "/$TAB" | head -n 1)"
victim_path="$(printf '%s\n' "$VICTIM" | cut -f1)"
victim_anchor="$(printf '%s\n' "$VICTIM" | cut -f2)"
assert_ne "" "$victim_path" "there is a file pin to damage"

# `want != ""` is not defensive noise: without it an empty construct — the very
# state the non-empty assertions above exist to catch — matches every line and
# empties the file, turning a broken parse into a green guard.
awk -v want="$victim_anchor" '
  { if (want != "" && index($0, want)) next; print }
' "$work/$victim_path" > "$work/$victim_path.tmp" \
  && mv "$work/$victim_path.tmp" "$work/$victim_path"

# Prove the damage landed before asserting the guard saw it: a copy that was
# never actually edited would fail the comparison for no reason at all.
assert_not_contains "$(cat "$work/$victim_path")" "$victim_anchor" \
  "the construct is gone from the mirrored file"
assert_eq "$victim_path :: $victim_anchor (construct not found)" \
  "$(unresolved "$PINS" "$work")" \
  "the comparison names exactly the deleted construct"

test_case "a marker naming a file that does not exist fails the check"
# The second negative control: a skill can rot by pinning a file that was moved
# or deleted, which no amount of reading the surviving files reveals.
bogus="src/skills/sift-drain/references/no-such-reference.md"
assert_no_file "$REPO_ROOT/$bogus" "the bogus path really is absent from the tree"
doc="$(printf '%s\n' "$DOCS" | head -n 1)"
damaged="$(newdir)/$(basename "$doc")"
awk -v tag="$MARKER" -v repl="$MARKER $bogus $victim_anchor" '
  !hit { line = $0; sub(/^[[:space:]]+/, "", line)
         if (index(line, tag) == 1) { print repl; hit = 1; next } }
  { print }
' "$REPO_ROOT/$doc" > "$damaged"
assert_eq "$bogus $victim_anchor" \
  "$(pins_of "$damaged" | head -n 1 | tr "$TAB" ' ')" \
  "the damaged document pins the missing file"
assert_eq "$bogus :: $victim_anchor (no such file)" \
  "$(unresolved "$(pins_of "$damaged" | head -n 1)" "$REPO_ROOT")" \
  "the comparison names exactly the missing file"

summary
