#!/usr/bin/env bash
# The XSD drafting schemas (SFT-0012, widened by SFT-0054).
#
# The schemas are scaffolding a drafter reads, never storage, so the assertions
# that matter without a tool are textual: the ticket-ID pattern must not pin a
# four-digit suffix, because allocation renders %04d as a *minimum* width and a
# tree that passes <PREFIX>-9999 keeps going. When xmllint happens to be
# installed the same claim is checked by machine, but its absence costs nothing
# — that is the rule the convention sets for every optional binary.
#
# The rule cuts both ways, and until SFT-0054 the absence bought nothing either.
# README's worked draft and the render-mapping table beside it are the whole of
# the drafting instructions, and both were checked only inside the
# `command -v xmllint` arm at the bottom of this file — the table not even
# there. On the machine the convention actually targets, and which
# static/suite-contract.test.sh deliberately simulates by pinning
# `assert_no_file "$BIN/xmllint"`, a draft naming an element no schema declares
# shipped green. The two cases in the middle of this file close that: they
# extract both artifacts and compare them against schemas/*.xsd by text, using
# nothing outside the BASELINE list, so they hold on any machine.
#
# THE CEILING, so a later reader does not mistake those two cases for
# validation. They are a lexical read of `xs:element name="…"`: they see element
# names, their nesting depth, their declared order and `minOccurs="0"`, and
# nothing else. Datatypes, patterns, enumerations and every cardinality beyond
# "optional or not" are outside what they can say — the ticket-ID pattern stays
# covered by the textual case at the top of this file, and the rest by xmllint
# on the machines that happen to have it. That arm is kept for exactly that
# reason, and its `skip` names only what is genuinely lost without it.
#
# Extraction is from the repository-root README.md alone. The shipped mirror
# src/skills/sift-init/assets/README.md is held byte-identical to it by
# tests/scripts/convention-assets.test.sh, so extracting there too would pin a
# copy of a copy.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

SCHEMAS="$REPO_ROOT/schemas"
COMMON="$SCHEMAS/sift-common.xsd"

test_case "the ticket-ID pattern is open-ended"
# What the pattern ACCEPTS, driven over a fixture list rather than compared
# against a literal copy of it. The claim the case is named for is that the
# numeric suffix is an unbounded digit run — `%04d` is a minimum width — so a
# four-digit cap has to fail here in EVERY spelling of it, while an equivalent
# respelling of the run (`[0-9][0-9]*` for `[0-9]+`) has to keep passing.
#
# One translation, written down because it is the case's only assumption: an XSD
# `xs:pattern` is implicitly anchored at both ends and XML Schema regex is not
# ERE, so the extracted value is wrapped in ^…$ before grep -E sees it, and the
# fixture stays inside the subset where the two agree — bracket expressions over
# ASCII, `*` and `+`, and nothing else. Everything it uses is baseline userland,
# so it runs on a host with no xmllint, which is the host that matters.
pattern="$(grep -A2 '<xs:simpleType name="ticketId">' "$COMMON" | grep 'xs:pattern')"
assert_ne "" "$pattern" "the ticketId pattern extracts from sift-common.xsd"
ticket_id_re="$(printf '%s\n' "$pattern" | sed -e 's/.*value="//' -e 's/".*//')"
assert_ne "" "$ticket_id_re" "…and its value reads out of the attribute"

# id_verdict <candidate> — what the extracted pattern says about one spelling.
id_verdict() {
  if printf '%s\n' "$1" | grep -qE "^$ticket_id_re\$"; then echo accepted; else echo refused; fi
}
for id in SFT-0042 SFT-10000; do
  assert_eq accepted "$(id_verdict "$id")" "$id is a ticket ID"
done
# Case, an empty suffix, a non-digit suffix, and trailing junk: the four ways a
# candidate falls outside the pattern without touching the width of the run.
for id in sft-0042 SFT- SFT-x SFT-0042x; do
  assert_eq refused "$(id_verdict "$id")" "$id is not a ticket ID"
done

test_case "the closed type set is written out three times and says the same thing each time"
# The set is the category folder set as well as the front-matter value set, so
# the three copies below are one API written three ways: the `<category>` comment
# in README's layout tree, the `type:` comment in its front-matter example, and
# this enumeration. Nothing compared them until SFT-0052, and a copy edited alone
# is invisible to a reader who happens to open one of the other two.
LAYOUT_TYPES="$(readme_layout_types)"
FM_TYPES="$(readme_frontmatter_types)"
XSD_TYPES="$(xsd_enum type)"
assert_ne "" "$LAYOUT_TYPES" "the layout block's <category> alternation extracts"
assert_ne "" "$FM_TYPES" "the front-matter example's type: alternation extracts"
assert_ne "" "$XSD_TYPES" "the XSD's type enumeration extracts"
# Both directions on each pair: a withdrawal is a member the other copy still has,
# which a one-way comparison never sees.
assert_eq "" "$(set_diff "$LAYOUT_TYPES" "$FM_TYPES")" \
  "no category the layout draws that the front-matter example does not allow"
assert_eq "" "$(set_diff "$FM_TYPES" "$LAYOUT_TYPES")" \
  "…and none the example allows that the layout does not draw"
assert_eq "" "$(set_diff "$FM_TYPES" "$XSD_TYPES")" \
  "no documented type the schema would reject"
assert_eq "" "$(set_diff "$XSD_TYPES" "$FM_TYPES")" \
  "…and none the schema accepts that the spec does not document"

# --- Reading the draft, the table and the schemas (SFT-0054) -----------------
#
# Four readers, all built from awk and index()/substr() alone. They live here
# rather than in lib/recipes.sh because this is their only client: recipes.sh is
# the cookbook's fenced-block reader, and a table extractor with one caller
# would be a second thing to keep in step for no gain.
#
# Nothing below restates a list. Every set on both sides of every comparison is
# extracted, and every case asserts its extractions are non-empty before it
# compares anything: a parse that silently yields nothing satisfies "each name is
# declared" vacuously and reports agreement on a spec that says nothing at all —
# the SFT-0010 shape, and the same guard tests/static/prompt-readme-sections.test.sh
# puts in front of its own comparison.

# xml_elements — read an XML document on stdin, print `<depth>\t<name>` for each
# element it OPENS, in document order. Depth 0 is the root.
#
# A scanner over `<`…`>` rather than a line matcher, because the draft writes
# `<labels><label>api</label></labels>` on one line. Names are cut with index()
# and a POSIX character class, never with a bracket expression holding a
# backslash — AGENTS.md bans that spelling outright.
xml_elements() {
  awk '
    BEGIN { depth = 0 }
    {
      line = $0
      while ((p = index(line, "<")) > 0) {
        line = substr(line, p + 1)
        e = index(line, ">")
        if (e == 0) break
        tag = substr(line, 1, e - 1)
        line = substr(line, e + 1)
        c = substr(tag, 1, 1)
        if (c == "?" || c == "!") continue           # declaration or comment
        if (c == "/") { depth--; continue }          # closing tag
        selfclose = (substr(tag, length(tag), 1) == "/")
        name = tag
        sub(/[[:space:]].*$/, "", name)
        q = index(name, "/"); if (q) name = substr(name, 1, q - 1)
        printf "%d\t%s\n", depth, name
        if (!selfclose) depth++
      }
    }
  '
}

# xsd_decls <file> [complexType-name] — print `<depth>\t<required>\t<name>` for
# every `xs:element name="…"` the file declares, in declaration order. Depth
# counts xs:element nesting only, so the root element of a ticket schema is 0 and
# its sequence members are 1. Given a complexType name, the read is scoped to
# that group and its nesting is counted from 0 (which is how the `frontMatter`
# group is read).
#
# `required` is 1 when the declaration itself lacks `minOccurs="0"` AND every
# enclosing declaration is required too: `<step>` is mandatory inside
# `<steps-to-reproduce>`, but the parent is optional, so a draft that omits both
# is still correct.
#
# Line-oriented on purpose — every declaration in schemas/ is written on one
# line, and a wrapped one would drop out of the read rather than be
# misread, which the non-empty assertions in each case turn into a failure.
xsd_decls() {
  awk -v scope="${2:-}" '
    BEGIN { depth = 0 }
    scope != "" && !inscope {
      if (index($0, "<xs:complexType name=\"" scope "\">")) { inscope = 1; ct = 1 }
      next
    }
    scope != "" {
      if (index($0, "<xs:complexType")) ct++
      if (index($0, "</xs:complexType>")) { ct--; if (ct == 0) exit }
    }
    index($0, "</xs:element>") { depth--; next }
    index($0, "<xs:element ") == 0 { next }
    !match($0, /name="[^"]*"/) { next }
    {
      name = substr($0, RSTART + 6, RLENGTH - 7)
      opt = (index($0, "minOccurs=\"0\"") > 0)
      req[depth] = (depth == 0 ? !opt : (req[depth - 1] && !opt))
      printf "%d\t%d\t%s\n", depth, req[depth], name
      if (index($0, "/>") == 0) depth++
    }
  ' "$1"
}

# Filters over either reader's output: the name is always the last field.
elements_at()   { awk -F'\t' -v d="$1" '$1 == d { print $NF }'; }
element_names() { awk -F'\t' '{ print $NF }'; }
required_names() { awk -F'\t' '$2 == 1 { print $3 }'; }

# xsd_declared_names — every element name declared anywhere in schemas/.
xsd_declared_names() {
  cat "$SCHEMAS"/*.xsd | awk '
    index($0, "<xs:element ") == 0 { next }
    match($0, /name="[^"]*"/) { print substr($0, RSTART + 6, RLENGTH - 7) }
  ' | LC_ALL=C sort -u
}

# subsequence_break <candidate> <reference> — empty when every line of
# <candidate> occurs in <reference> in the same relative order; otherwise the
# first candidate line that could not be matched without going backwards.
#
# A subsequence and not equality: optional elements may be omitted from a draft,
# so the draft is allowed to be shorter than the declared sequence. It is not
# allowed to be out of order — the schemas say outright that element order is the
# rendered section order.
subsequence_break() {
  printf '%s\n' "$1" | awk -v ref="$2" '
    BEGIN { n = split(ref, R, "\n"); j = 0 }
    $0 == "" { next }
    {
      hit = 0
      while (j < n) { j++; if (R[j] == $0) { hit = 1; break } }
      if (!hit) { print; exit }
    }
  '
}

# The three comparisons the draft case makes, each taking the draft TEXT so the
# negative controls at the end of that case can run the identical code against a
# deliberately damaged copy. A guard proven only on the tree that already passes
# is not proven at all.
draft_undeclared() {  # draft_undeclared <draft-text>
  set_diff "$(printf '%s\n' "$1" | xml_elements | element_names | LC_ALL=C sort -u)" \
    "$DECLARED"
}
draft_order_break() {  # draft_order_break <draft-text>
  subsequence_break "$(printf '%s\n' "$1" | xml_elements | elements_at 1)" "$BUG_ROOT_SEQ"
}
draft_missing_required() {  # draft_missing_required <draft-text>
  set_diff "$DRAFT_REQUIRED" "$(printf '%s\n' "$1" | xml_elements | element_names)"
}

DRAFT="$(readme_block 'Draft into a scratch file outside')"
DECLARED="$(xsd_declared_names)"
BUG_ROOT_SEQ="$(xsd_decls "$SCHEMAS/bug-ticket.xsd" | elements_at 1)"
# The required set the draft has to satisfy: bug-ticket.xsd's own declarations
# plus the frontMatter group it pulls in from sift-common.xsd by type reference,
# which a per-file read would miss entirely.
DRAFT_REQUIRED="$(
  xsd_decls "$SCHEMAS/bug-ticket.xsd" | required_names
  xsd_decls "$COMMON" frontMatter | required_names
)"
# The two elements the negative controls damage, taken from the schema's own
# required root sequence rather than named here: a rename in bug-ticket.xsd
# retargets the damage instead of quietly disarming the control.
BUG_ROOT_REQ="$(xsd_decls "$SCHEMAS/bug-ticket.xsd" | awk -F'\t' '$1 == 1 && $2 == 1 { print $3 }')"
VICTIM_A="$(printf '%s\n' "$BUG_ROOT_REQ" | sed -n '2p')"
VICTIM_B="$(printf '%s\n' "$BUG_ROOT_REQ" | sed -n '3p')"

# @BASELINE-CASE on the two `test_case` lines below is read by
# tests/static/suite-contract.test.sh, which extracts those names and asserts an
# `ok` line for each from a run of this file under the baseline symlink farm.
# The tag is the claim "this case must not need an installable binary"; moving
# either case back inside the `command -v xmllint` arm makes that run stop
# printing its `ok` lines and turns the contract case red.
test_case "the worked draft opens only elements the schemas declare, in the declared order"  # @BASELINE-CASE
assert_ne "" "$DRAFT" "the worked draft extracts from README.md"
assert_contains "$DRAFT" '<bug-ticket xmlns="urn:sift:ticket:v1">' \
  "and it is the bug-ticket draft the schemas are read against"
assert_ne "" "$DECLARED" "the schemas' element declarations extract"
assert_ne "" "$BUG_ROOT_SEQ" "bug-ticket.xsd's root sequence extracts"
assert_ne "" "$DRAFT_REQUIRED" "the required declarations extract"
assert_ne "" "$VICTIM_A" "there is a required root element to damage"
assert_ne "" "$VICTIM_B" "…and a second one beside it"

assert_eq "" "$(draft_undeclared "$DRAFT")" \
  "every element the draft opens is declared in schemas/"
assert_eq "" "$(draft_order_break "$DRAFT")" \
  "…and its top-level sequence follows the order bug-ticket.xsd declares"
assert_eq "" "$(draft_missing_required "$DRAFT")" \
  "…and every declaration without minOccurs=\"0\" is in it"

# Control 1 — an element no schema declares. `<step>` is renamed rather than a
# root child, so the undeclared check is the only one that can see the damage.
renamed="$(printf '%s\n' "$DRAFT" | sed 's|<step>|<invented-step>|g')"
assert_contains "$renamed" '<invented-step>' "the damaged copy really renames an element"
assert_eq 'invented-step' "$(draft_undeclared "$renamed")" \
  "an element no schema declares is named by the comparison"

# Control 2 — two siblings swapped. Both names stay declared and both stay
# present, so only the order comparison can catch it; that is what it is for.
swapped="$(printf '%s\n' "$DRAFT" | sed \
  -e "s|<$VICTIM_A>|<SIFT-0054-SWAP>|g" \
  -e "s|<$VICTIM_B>|<$VICTIM_A>|g" \
  -e "s|<SIFT-0054-SWAP>|<$VICTIM_B>|g")"
assert_ne "$(printf '%s\n' "$DRAFT" | xml_elements | elements_at 1)" \
  "$(printf '%s\n' "$swapped" | xml_elements | elements_at 1)" \
  "the damaged copy really reorders two siblings"
assert_eq "" "$(draft_undeclared "$swapped")" \
  "a swap leaves every name declared, so the first comparison cannot see it"
assert_eq "$VICTIM_A" "$(draft_order_break "$swapped")" \
  "…and the order comparison names the element that moved"

# Control 3 — a required element removed. An omission is still a subsequence, so
# only the required comparison can catch this one.
stripped="$(printf '%s\n' "$DRAFT" | grep -v "<$VICTIM_A>")"
assert_not_contains "$stripped" "<$VICTIM_A>" "the damaged copy really drops a required element"
assert_eq "" "$(draft_order_break "$stripped")" \
  "an omission is still an ordered subsequence, so the order comparison cannot see it"
assert_eq "$VICTIM_A" "$(draft_missing_required "$stripped")" \
  "…and the required comparison names the element that went missing"

# --- The render-mapping table ------------------------------------------------

# mapping_rows — read README.md on stdin, print `<left-cell>\t<right-cell>` for
# each row of the table under the `| Draft element | Renders to |` header,
# stopping at the first line that is not a table row.
#
# The table is not fenced, so readme_block cannot reach it; this is the only
# reader in the suite that wants a markdown table cell out of the spec.
mapping_rows() {
  awk '
    !found { if (index($0, "| Draft element | Renders to |")) found = 1; next }
    substr($0, 1, 1) != "|" { exit }
    substr($0, 1, 2) == "|-" { next }
    {
      n = split($0, cell, "|")
      if (n < 4) next
      printf "%s\t%s\n", cell[2], cell[3]
    }
  '
}

# backticked — every `…`-quoted span of the text on stdin, one per line.
backticked() {
  awk '
    {
      line = $0
      while ((p = index(line, "`")) > 0) {
        line = substr(line, p + 1)
        e = index(line, "`")
        if (e == 0) break
        print substr(line, 1, e - 1)
        line = substr(line, e + 1)
      }
    }
  '
}

# row_elements <rows> — every `<element>` spelling quoted in a left cell. A cell
# may hold several (`<steps-to-reproduce><step>`), so the angle brackets are
# scanned inside the quoted span rather than the span being taken whole.
row_elements() {
  printf '%s\n' "$1" | cut -f1 | backticked | awk '
    {
      line = $0
      while ((p = index(line, "<")) > 0) {
        line = substr(line, p + 1)
        e = index(line, ">")
        if (e == 0) break
        print substr(line, 1, e - 1)
        line = substr(line, e + 1)
      }
    }
  '
}

# row_headings <rows> — every `## …` heading quoted in a right cell, in row
# order. The other quoted spans on that side (`labels: [api, caching]`,
# `- [ ]`, `depends_on`) are rendering notes rather than headings and drop out.
row_headings() { printf '%s\n' "$1" | cut -f2 | backticked | grep '^## '; }

# The comparisons, again taking the extracted rows so the controls can damage a
# copy and run the identical code.
table_undeclared()       { set_diff "$(row_elements "$1")" "$DECLARED"; }
table_unknown_headings() { set_diff "$(row_headings "$1")" "$TEMPLATE_HEADINGS"; }
table_missing_rows()     { set_diff "$BODY_ELEMENTS" "$(row_elements "$1")"; }

TABLE="$(mapping_rows < "$README")"
# The headings the table's right column has to resolve against. Read from INSIDE
# the three body-template fenced blocks, which is the opposite of what
# static/prompt-readme-sections.test.sh does and is deliberate: these headings
# exist in README.md only as template content, so a reader matching live `##`
# headings the way that file does would find none of them. Do not "fix" it.
TEMPLATE_HEADINGS="$(
  { readme_body_canonical; readme_body_bug; readme_body_feature; } \
    | block_headings | LC_ALL=C sort -u
)"

# The excused entry of the reverse check, with its reason — the only one, and it
# is not a gap:
#   front-matter  the table covers its children with a single `<front-matter>`
#                 children row rather than a row per key, so a per-element
#                 reverse check would fail on a tree that is correct today. The
#                 row itself is still required to exist, which the case asserts.
# The three root element names never enter the set at all: they are depth 0 in
# their own file while the reverse check reads depth 1, and the spec covers them
# in the "Which root element to use" sentence under the table rather than in a
# row of it.
TABLE_ROW_EXCUSED='front-matter'
BODY_ELEMENTS="$(
  for f in bug feature task; do
    xsd_decls "$SCHEMAS/$f-ticket.xsd" | elements_at 1
  done | grep -Fxv -e "$TABLE_ROW_EXCUSED" | LC_ALL=C sort -u
)"

test_case "both columns of the render-mapping table resolve"  # @BASELINE-CASE
assert_ne "" "$TABLE" "the render-mapping table extracts from README.md"
assert_ne "" "$(readme_body_canonical)" "the canonical body template extracts"
assert_ne "" "$(readme_body_bug)" "the bug body template extracts"
assert_ne "" "$(readme_body_feature)" "the feature body template extracts"
assert_ne "" "$TEMPLATE_HEADINGS" "their headings extract"
assert_ne "" "$(row_elements "$TABLE")" "the left column's element spellings extract"
assert_ne "" "$(row_headings "$TABLE")" "the right column's headings extract"
assert_ne "" "$BODY_ELEMENTS" "the three schemas' body sequences extract"

assert_eq "" "$(table_undeclared "$TABLE")" \
  "every element the left column names is declared in schemas/"
assert_eq "" "$(table_unknown_headings "$TABLE")" \
  "every heading the right column promises is in a body template"
assert_eq "" "$(table_missing_rows "$TABLE")" \
  "every body element the three schemas declare has a row"
assert_eq "" "$(set_diff "$TABLE_ROW_EXCUSED" "$(row_elements "$TABLE")")" \
  "and the one element excused from that reverse check still has its own row"

# Control 1 — a row pointing at an element no schema declares.
badrow="$(printf '%s\n' "$TABLE" | sed "s|<$VICTIM_A>|<no-such-element>|")"
assert_ne "$TABLE" "$badrow" "the damaged copy really rewrites a left cell"
assert_eq 'no-such-element' "$(table_undeclared "$badrow")" \
  "a left cell naming an undeclared element is caught"

# Control 2 — a row promising a heading no body template has.
victim_heading="$(printf '%s\n' "$(row_headings "$TABLE")" | sed -n '1p')"
assert_ne "" "$victim_heading" "there is a heading to damage"
badhead="$(printf '%s\n' "$TABLE" | sed "s|\`$victim_heading\`|\`$victim_heading renamed\`|")"
assert_ne "$TABLE" "$badhead" "the damaged copy really rewrites a right cell"
assert_eq "$victim_heading renamed" "$(table_unknown_headings "$badhead")" \
  "a right cell promising a section the spec does not have is caught"

# Control 3 — the reverse direction: a declared body element with no row at all.
droppedrow="$(printf '%s\n' "$TABLE" | grep -v "<$VICTIM_B>")"
assert_ne "$TABLE" "$droppedrow" "the damaged copy really drops a row"
assert_eq "$VICTIM_B" "$(table_missing_rows "$droppedrow")" \
  "a body element the schemas declare and the table skips is caught"

# --- The optional extra ------------------------------------------------------

test_case "README's worked draft validates, past four digits included"
if command -v xmllint > /dev/null 2>&1; then
  d="$(newdir)"
  cp "$SCHEMAS"/*.xsd "$d/"
  printf '%s\n' "$DRAFT" > "$d/draft.xml"
  assert_contains "$(cat "$d/draft.xml")" '<bug-ticket xmlns="urn:sift:ticket:v1">' \
    "the draft came out of README.md"

  run_cmd "$d" xmllint --noout --schema bug-ticket.xsd draft.xml
  assert_eq 0 "$R_STATUS" "the documented four-digit draft is valid"

  sed 's|ABCD-0042|ABCD-10042|' "$d/draft.xml" > "$d/wide.xml"
  run_cmd "$d" xmllint --noout --schema bug-ticket.xsd wide.xml
  assert_eq 0 "$R_STATUS" "a five-digit ID is valid too"

  sed 's|<id>ABCD-0042</id>|<id>abcd-0042</id>|' "$d/draft.xml" > "$d/bad.xml"
  run_cmd "$d" xmllint --noout --schema bug-ticket.xsd bad.xml
  assert_ne 0 "$R_STATUS" "a lowercase prefix is still rejected"
else
  skip "datatype, date and ticket-ID pattern validation of a rendered draft" \
    "xmllint not installed; the draft's element set, order and required members are asserted above"
fi

summary
