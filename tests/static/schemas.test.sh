#!/usr/bin/env bash
# The XSD drafting schemas (SFT-0012).
#
# The schemas are scaffolding a drafter reads, never storage, so the assertions
# that matter without a tool are textual: the ticket-ID pattern must not pin a
# four-digit suffix, because allocation renders %04d as a *minimum* width and a
# tree that passes <PREFIX>-9999 keeps going. When xmllint happens to be
# installed the same claim is checked by machine, but its absence costs nothing
# — that is the rule the convention sets for every optional binary.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

COMMON="$REPO_ROOT/schemas/sift-common.xsd"

test_case "the ticket-ID pattern is open-ended"
pattern="$(grep -A2 '<xs:simpleType name="ticketId">' "$COMMON" | grep 'xs:pattern')"
assert_contains "$pattern" '[A-Z][A-Z0-9]*-[0-9]+' "the numeric suffix is a digit run"
assert_not_contains "$pattern" '{4}' "no four-digit cap"
assert_not_contains "$pattern" '[0-9][0-9][0-9][0-9]' "…in either spelling"

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

test_case "README's worked draft validates, past four digits included"
if command -v xmllint > /dev/null 2>&1; then
  d="$(newdir)"
  cp "$REPO_ROOT/schemas"/*.xsd "$d/"
  readme_block 'Draft into a scratch file outside' > "$d/draft.xml"
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
  skip "machine validation of a rendered draft" "xmllint not installed; the pattern is asserted textually"
fi

summary
