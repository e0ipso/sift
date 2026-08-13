#!/usr/bin/env bash
# Static analysis: numbered README rule citations in sift-prime reference docs.
#
# A citation such as "rule 5" names an ordered-list position, not a stable
# construct. The sentence can therefore stay plausible while an inserted or
# reordered rule silently points it somewhere else. Each citing document carries
# `@RULE:` markers whose substrings come from the cited rules, and this file
# extracts those markers rather than restating their list.
#
# The resolver reads only README.md's `## Rules for agents` section, skips fenced
# blocks, and folds indented continuation lines into the item they continue. It
# checks both meanings of a markdown list number: the literal digit written in
# the source must equal the item's position, and every marker substring must
# occur in exactly one item at its cited position.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

MARKER='@RULE:'
SELF="tests/static/$(basename "$0")"
TAB="$(printf '\t')"
DOCS="$REPO_ROOT/src/skills/sift-prime/references/drafting-agent-prompt.md
$REPO_ROOT/src/skills/sift-prime/references/analysis.md"

# marker_lines_of <document> — every line that claims to be a marker, including
# a malformed one. This lets the test compare the raw and parsed counts rather
# than silently dropping a marker whose target, ordinal or substring is empty.
marker_lines_of() {
  awk -v tag="$MARKER" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, tag) == 1) printf "%d\t%s\n", NR, line
    }
  ' "$1"
}

# markers_of <document> — one
# "<document><TAB><line><TAB><target><TAB><ordinal><TAB><substring>" record per
# well-formed marker, in document order. Duplicate records stay duplicated:
# the two rule-5 sentences in analysis.md are two independently guarded sites.
markers_of() {
  local document="$1" relative
  relative="${document#"$REPO_ROOT/"}"
  awk -v tag="$MARKER" -v document="$relative" '
    {
      marker = $0
      sub(/^[[:space:]]+/, "", marker)
      sub(/[[:space:]]+$/, "", marker)
      if (index(marker, tag) != 1) next

      marker = substr(marker, length(tag) + 1)
      sub(/^[[:space:]]+/, "", marker)
      target = marker
      sub(/[[:space:]].*$/, "", target)

      rest = substr(marker, length(target) + 1)
      sub(/^[[:space:]]+/, "", rest)
      ordinal = rest
      sub(/[[:space:]].*$/, "", ordinal)

      construct = substr(rest, length(ordinal) + 1)
      sub(/^[[:space:]]+/, "", construct)
      if (target != "" && ordinal != "" && construct != "")
        printf "%s\t%d\t%s\t%s\t%s\n", document, NR, target, ordinal, construct
    }
  ' "$document"
}

all_markers() {
  printf '%s\n' "$DOCS" | while IFS= read -r document; do
    [ -n "$document" ] || continue
    markers_of "$document"
  done
}

# rules_of <spec> — one
# "<position><TAB><literal digit><TAB><physical lines><TAB><flattened text>"
# record per ordered-list item in the bounded Rules for agents section.
rules_of() {
  awk '
    function flush_item() {
      if (!have_item) return
      printf "%d\t%s\t%d\t%s\n", position, literal, physical_lines, text
      have_item = 0
    }

    /^[[:space:]]*```/ { in_fence = !in_fence; next }
    in_fence { next }

    $0 == "## Rules for agents" { in_rules = 1; next }
    in_rules && /^##[[:space:]]/ { flush_item(); in_rules = 0; exit }
    !in_rules { next }

    /^[0-9][0-9]*\.[[:space:]]/ {
      flush_item()
      position++
      literal = $0
      sub(/\..*$/, "", literal)
      text = $0
      sub(/^[0-9][0-9]*\.[[:space:]]*/, "", text)
      sub(/[[:space:]]+$/, "", text)
      physical_lines = 1
      have_item = 1
      next
    }

    have_item && /^[[:space:]]/ && $0 !~ /^[[:space:]]*$/ {
      continuation = $0
      sub(/^[[:space:]]+/, "", continuation)
      sub(/[[:space:]]+$/, "", continuation)
      text = text " " continuation
      physical_lines++
    }

    END { flush_item() }
  ' "$1"
}

rule_count() {
  rules_of "$1" | awk 'NF { count++ } END { print count + 0 }'
}

rule_span() {
  RULE_POSITION="$2" rules_of "$1" | awk -F "$TAB" '
    $1 == ENVIRON["RULE_POSITION"] { print $3; exit }
  '
}

rule_text() {
  RULE_POSITION="$2" rules_of "$1" | awk -F "$TAB" '
    $1 == ENVIRON["RULE_POSITION"] { print $4; exit }
  '
}

literal_mismatches() {
  rules_of "$1" | awk -F "$TAB" '
    $1 != $2 { printf "item at position %s is written with literal digit %s\n", $1, $2 }
  '
}

# unresolved <markers> <spec> — one diagnostic per marker whose substring is
# absent, non-unique or found at a different position. Empty means agreement.
# This is the comparison both negative controls run unchanged against copies.
unresolved() {
  local markers="$1" spec="$2" rules
  local document source_line target cited construct label positions count joined
  rules="$(rules_of "$spec")"

  printf '%s\n' "$markers" \
    | while IFS="$TAB" read -r document source_line target cited construct; do
        [ -n "$document" ] || continue
        label="$document:$source_line :: $MARKER $target $cited $construct"

        if [ "$target" != 'README.md' ]; then
          printf '%s (target must be README.md)\n' "$label"
          continue
        fi
        case "$cited" in
          ''|*[!0123456789]*)
            printf '%s (ordinal is not a positive integer)\n' "$label"
            continue
            ;;
        esac
        if [ "$cited" -eq 0 ]; then
          printf '%s (ordinal is not a positive integer)\n' "$label"
          continue
        fi

        positions="$(printf '%s\n' "$rules" | RULE_NEEDLE="$construct" \
          awk -F "$TAB" 'index($4, ENVIRON["RULE_NEEDLE"]) { print $1 }')"
        count="$(printf '%s\n' "$positions" | awk 'NF { count++ } END { print count + 0 }')"
        joined="$(printf '%s\n' "$positions" \
          | awk 'NF { if (seen++) printf ", "; printf "%s", $0 }')"

        case "$count" in
          0) printf '%s (substring not found)\n' "$label" ;;
          1) [ "$joined" = "$cited" ] \
               || printf '%s (found at position %s, cited as %s)\n' \
                    "$label" "$joined" "$cited" ;;
          *) printf '%s (found at positions %s; cited as %s)\n' \
               "$label" "$joined" "$cited" ;;
        esac
      done
}

compare_claims() {
  literal_mismatches "$1"
  unresolved "$MARKERS" "$1"
}

# insert_rule_before <spec> <position> — insert an item and renumber every
# following literal so only ordinal movement, not malformed markdown numbering,
# makes the identical comparison fail.
insert_rule_before() {
  local spec="$1" position="$2"
  awk -v insert_at="$position" '
    /^[[:space:]]*```/ { in_fence = !in_fence; print; next }
    !in_fence && $0 == "## Rules for agents" { in_rules = 1; print; next }
    !in_fence && in_rules && /^##[[:space:]]/ { in_rules = 0; print; next }

    !in_fence && in_rules && /^[0-9][0-9]*\.[[:space:]]/ {
      old_position++
      rest = $0
      sub(/^[0-9][0-9]*\./, "", rest)
      if (old_position == insert_at) {
        printf "%d. **Inserted by the reorder control.**\n", insert_at
        shifted = 1
      }
      printf "%d.%s\n", old_position + shifted, rest
      next
    }

    { print }
  ' "$spec" > "$spec.tmp" && mv "$spec.tmp" "$spec"
}

# reword_marker_construct <spec> <position> <substring> — replace one fixed
# substring only inside its cited item. ENVIRON preserves backslashes verbatim;
# awk -v would interpret them before the program receives the marker text.
reword_marker_construct() {
  local spec="$1" position="$2" construct="$3"
  RULE_NEEDLE="$construct" awk -v change_at="$position" '
    BEGIN { needle = ENVIRON["RULE_NEEDLE"] }
    /^[[:space:]]*```/ { in_fence = !in_fence; print; next }
    !in_fence && $0 == "## Rules for agents" { in_rules = 1; print; next }
    !in_fence && in_rules && /^##[[:space:]]/ { in_rules = 0; print; next }
    !in_fence && in_rules && /^[0-9][0-9]*\.[[:space:]]/ { position++ }
    !in_fence && in_rules && position == change_at && needle != "" {
      found = index($0, needle)
      if (found)
        $0 = substr($0, 1, found - 1) "reworded by the content control" \
             substr($0, found + length(needle))
    }
    { print }
  ' "$spec" > "$spec.tmp" && mv "$spec.tmp" "$spec"
}

MARKERS="$(all_markers)"
MARKER_COUNT="$(printf '%s' "$MARKERS" | grep -c '' || [ $? -eq 1 ])"
: "${MARKER_COUNT:=0}"

test_case "both documents expose well-formed markers and name their reader"
for document in $DOCS; do
  raw="$(marker_lines_of "$document")"
  parsed="$(markers_of "$document")"
  raw_count="$(printf '%s' "$raw" | grep -c '' || [ $? -eq 1 ])"
  parsed_count="$(printf '%s' "$parsed" | grep -c '' || [ $? -eq 1 ])"
  : "${raw_count:=0}"
  : "${parsed_count:=0}"
  assert_file "$document" "$(basename "$document") is present"
  assert_ne 0 "$raw_count" "$(basename "$document") carries at least one $MARKER marker"
  assert_eq "$raw_count" "$parsed_count" "every marker in $(basename "$document") is complete"
  if grep -Fq -e "$SELF" "$document"; then
    t_ok "$(basename "$document") names the test that reads it"
  else
    t_fail "$(basename "$document") names the test that reads it" "missing: $SELF"
  fi
done
assert_ne 0 "$MARKER_COUNT" "the combined marker list is not empty"

targets="$(printf '%s\n' "$MARKERS" | cut -f3 | LC_ALL=C sort -u)"
assert_eq 'README.md' "$targets" "every ordinal resolves against root README.md only"

test_case "the bounded README list and every live citation agree"
COUNT="$(rule_count "$README")"
assert_ne 0 "$COUNT" "the bounded Rules for agents list is not empty"
assert_eq '' "$(literal_mismatches "$README")" \
  "every item's literal digit equals its position"
assert_ne 1 "$(rule_span "$README" 9)" "rule 9 includes indented continuation lines"
assert_ne 1 "$(rule_span "$README" 10)" "rule 10 includes indented continuation lines"
assert_eq '' "$(compare_claims "$README")" \
  "all $MARKER_COUNT extracted markers resolve uniquely at their cited positions"

test_case "an inserted rule fails the identical comparison with the moved position"
work="$(newdir)"
copy="$work/README.md"
cp "$README" "$copy"
VICTIM="$(printf '%s\n' "$MARKERS" | head -n 1)"
victim_document="$(printf '%s\n' "$VICTIM" | cut -f1)"
victim_line="$(printf '%s\n' "$VICTIM" | cut -f2)"
victim_target="$(printf '%s\n' "$VICTIM" | cut -f3)"
victim_ordinal="$(printf '%s\n' "$VICTIM" | cut -f4)"
victim_construct="$(printf '%s\n' "$VICTIM" | cut -f5-)"
victim_label="$victim_document:$victim_line :: $MARKER $victim_target $victim_ordinal $victim_construct"
assert_ne '' "$VICTIM" "there is a marker whose cited item can move"
assert_eq '' "$(compare_claims "$copy")" "the untouched copy agrees"
insert_rule_before "$copy" "$victim_ordinal"
assert_eq "$((COUNT + 1))" "$(rule_count "$copy")" "one ordered-list item was inserted"
assert_eq '' "$(literal_mismatches "$copy")" "the damaged copy still has honest literal digits"
reordered="$(compare_claims "$copy")"
assert_contains "$reordered" \
  "$victim_label (found at position $((victim_ordinal + 1)), cited as $victim_ordinal)" \
  "the comparison names the citation and the position its rule moved to"

test_case "a reworded rule fails the identical comparison with exactly its marker"
work="$(newdir)"
copy="$work/README.md"
cp "$README" "$copy"
assert_eq '' "$(compare_claims "$copy")" "the untouched copy agrees"
reword_marker_construct "$copy" "$victim_ordinal" "$victim_construct"
assert_not_contains "$(rule_text "$copy" "$victim_ordinal")" "$victim_construct" \
  "the pinned substring is gone from the cited item"
assert_eq "$victim_label (substring not found)" "$(compare_claims "$copy")" \
  "the comparison names exactly the marker whose rule text changed"

summary
