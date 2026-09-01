#!/usr/bin/env bash
# existing-work.sh and reserve-ids.sh — what priming asks, and what it hands out
# (SFT-0019).
#
# One priming pass reads twice and writes nothing of its own: `existing-work.sh`
# answers, for one candidate at a time, which tickets already carry that
# candidate's terms, and `reserve-ids.sh` hands each drafting agent the one ID it
# may use. They are pinned together because they are the two reads that decide
# what a batch becomes — what is already filed, and what the new work is called.
#
# The query is held from both sides, because either side alone is satisfied by a
# script that stopped working: the rows a term must return, and the rows it must
# not. A term no ticket carries, no term at all, and an empty term each print
# nothing, and every one of those assertions sits beside a query on the SAME tree
# that does return rows — without that control, a script deleted from disk would
# pass them all. The empty term earns a case of its own because `grep -F -e ""`
# selects every file: an unset caller variable is the one way left for the
# full-backlog dump this script no longer prints to come back silently.
#
# Each returned row stakes everything on one promise: a tab must never appear
# where a tab means "next field", so the reader squashes one out of a front-matter
# value rather than letting its five-field TSV shift the `resolution` column.
#
# What the whole answer costs is held here too: at most SIFT_MATCH_LIMIT rows,
# each with a resolution of at most 200 characters, whatever the terms and
# however large the archive. Both caps are pinned at
# their boundary, each with the control that proves the cap was the only thing
# limiting — a raised cap returning every row, and a resolution one character
# short of the cut coming back unmarked. The overflow notice is asserted beside
# them because it is the only place an incomplete answer says so: twenty-five
# valid records look exactly like a complete answer, and a drafter who reads them
# as one concludes "no prior work" from a query that was cut off.
#
# The allocator carries sift-prime's copy of the cross-skill ID rule — it is the
# only place in this skill a ticket ID is spelled — so the agreement with
# sift-drain's require_ticket_id is measured here, on the IDs the allocator really
# emits rather than on a list restated in a test.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT. Root and prefix resolution are
# swept across both skills by root-resolution.test.sh; what is held here is the
# narrower claim that the two skills resolve the SAME prefix out of one tree,
# because the ID rule is only meaningful once they do.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

PRIME="$REPO_ROOT/src/skills/sift-prime/scripts"
WORK="$PRIME/existing-work.sh"
RESERVE="$PRIME/reserve-ids.sh"
DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"

TAB="$(printf '\t')"
NL="$(printf '\nx')"; NL="${NL%x}"

# work <root> [arg…] — the query through its real command line. Every argument
# after the root reaches the script untouched, so a case can drive a term, several
# terms, the `--` marker, an empty string, or nothing at all.
work() { local dir="$1"; shift; run_cmd "$dir" env SIFT_ROOT="$dir" "$WORK" "$@"; }

# work_limit <root> <limit> [arg…] — the same query with the row cap handed to it
# through the environment, which is the only way a caller sets it.
work_limit() {
  local dir="$1" lim="$2"; shift 2
  run_cmd "$dir" env SIFT_ROOT="$dir" SIFT_MATCH_LIMIT="$lim" "$WORK" "$@"
}

# tsv_widths — every distinct field count across R_OUT.
tsv_widths() {
  printf '%s\n' "$R_OUT" | awk -F'\t' '{ print NF }' | LC_ALL=C sort -u |
    tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# row_ids — the ID column of R_OUT on one line, in the order it was printed. Which
# tickets an answer names, and in what order, is most of what a query promises, so
# the two are read together rather than through a per-row grep.
row_ids() {
  printf '%s\n' "$R_OUT" | cut -f 1 | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# row_count — how many records R_OUT holds. Asserted beside the ID list rather
# than derived from it, because the cap is a claim about a number of rows and a
# reader has to see that number stated.
row_count() { printf '%s\n' "$R_OUT" | wc -l | tr -d '[:space:]'; }

# row_col <id> <n> — column <n> of the record for <id>. Selected on the whole
# first field rather than by a leading-anchor grep, so a resolution quoting
# another ticket's ID cannot pull in a second row.
row_col() {
  printf '%s\n' "$R_OUT" | awk -F'\t' -v id="$1" -v n="$2" '$1 == id { print $n }'
}

# fill <n> <char> — <n> copies of one character. The truncation fixtures are
# built around a character count, so their content carries no meaning and saying
# so in one helper keeps a 200-character literal out of the file.
fill() { printf '%*s' "$1" '' | tr ' ' "$2"; }

# acme_id <n> / acme_ids <first> <last> — the fixture IDs the cap cases rank and
# cut, and a contiguous run of them on one line for comparison against row_ids.
#
# Zero-padded to one fixed width on purpose: the tie-break sorts the ID column as
# TEXT, so equal-width IDs are what make "ascending ID" and "ascending number"
# the same rule. A fixture mixing widths would be pinning collation, not the
# tie-break.
acme_id() { printf 'ACME-%04d' "$1"; }
acme_ids() {
  local i out=''
  for ((i = $1; i <= $2; i++)); do out="$out $(acme_id "$i")"; done
  printf '%s' "${out# }"
}

# =============================================================================
# existing-work.sh — the collision query
# =============================================================================

test_case "a query against an empty backlog is empty, and succeeds"
# A fresh sift-init tree is the first state a priming pass meets, and "nothing
# filed yet" must not read as an error, nor as one blank record. The same term is
# then asked of a tree that does carry it: an empty answer is evidence of nothing
# on its own, since a script that had stopped reading the tree — or stopped
# existing — would satisfy the three assertions above.
d="$(newdir)"; make_tree "$d" ACME
work "$d" caching
assert_eq 0 "$R_STATUS" "exit 0 on a tree with no tickets"
assert_eq "" "$R_OUT" "and not one byte on stdout"
assert_eq "" "$R_ERR" "nor a complaint about the empty archive/"
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
work "$d" caching
assert_eq "ACME-0001" "$(row_ids)" \
  "while the same term on a tree that carries it returns the row"

test_case "every matching ticket in either bucket is one five-field record"
# One fixture, queried by the four cases below it: a term four of the five tickets
# carry, and a fifth ticket that carries none of it.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0002 beta 'Beta caching' > /dev/null
ticket "$d" open v1/feature ACME-0010 iota 'Iota caching' \
  'type: feature' 'status: blocked' > /dev/null
ticket "$d" archive v1/bug ACME-0001 alpha 'Alpha caching' \
  'status: done' 'resolution: "Fixed upstream"' > /dev/null
ticket "$d" archive v2/docs ACME-0003 gamma 'Gamma caching' \
  'status: wontfix' 'type: docs' 'resolution: "Superseded by ACME-0001"' > /dev/null
ticket "$d" open v1/bug ACME-0004 delta 'Delta sharding' > /dev/null
work "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" \
  "id, status, type, title, resolution — the same count on every line, open and archived"

test_case "the records are sorted by ID, whatever the tree looks like"
# The answer is read by a drafter checking "has this already been filed", so the
# order has to come from the ID and not from the order find happened to walk two
# buckets and four milestone folders.
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0010" "$(row_ids)" \
  "zero-padding makes the plain sort an ID sort, past the ninth ticket"

test_case "resolution is the column that separates filed from decided against"
assert_eq "ACME-0001${TAB}done${TAB}bug${TAB}Alpha caching${TAB}Fixed upstream" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "an archived ticket carries its closing line, unquoted"
assert_eq "ACME-0002${TAB}open${TAB}bug${TAB}Beta caching${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0002')" \
  "an open ticket leaves it empty rather than omitting the field"
assert_eq "ACME-0003${TAB}wontfix${TAB}docs${TAB}Gamma caching${TAB}Superseded by ACME-0001" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0003')" \
  "and a wontfix reads as decided against, which is the distinction it exists for"

test_case "a ticket the terms do not name is not in the answer"
# The other half of a query: what it leaves out. Asserted on the fixture above,
# which answered with four rows, so the absence is this ticket being filtered and
# not the whole answer being empty — and then proved live by a term that does name
# it, because an absence nobody can make present is not a filter.
assert_eq "" "$(printf '%s\n' "$R_OUT" | grep '^ACME-0004')" \
  "the sharding ticket is absent from a caching query"
assert_ne "" "$R_OUT" "on an answer that is not itself empty"
work "$d" sharding
assert_eq "ACME-0004" "$(row_ids)" \
  "and it comes back, alone, under the term it does carry"

test_case "a term no ticket carries is an empty answer, not an error"
# The candidate whose chosen words hit nothing. It is one refusal away from the
# usage error below and must not be confused with it: an empty answer is a verdict
# on the terms, and the caller's next move is other terms, not a bug report.
work "$d" quiescence
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "with nothing on stdout"
assert_eq "" "$R_ERR" "and nothing on stderr"
work "$d" caching
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0010" "$(row_ids)" \
  "on the same tree that answers a term it does carry with four rows"

test_case "a term only the body carries still finds the ticket"
# The false negative the whole-file scope exists to avoid: the drafter's word for
# a subject is rarely the word the ticket's title chose, and a title-only search
# would report "no prior work" on a ticket that is about exactly this.
d="$(newdir)"; make_tree "$d" ACME
f="$(ticket "$d" open v1/bug ACME-0001 alpha 'Alpha')"
printf 'The tenant caching layer is where the duplicate would be.\n' >> "$f"
ticket "$d" open v1/bug ACME-0002 beta 'Beta' > /dev/null
work "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}Alpha${TAB}" "$R_OUT" \
  "the row is returned although its own title column does not hold the term"

test_case "matching is case-insensitive, whichever side is capitalised"
# A candidate is described in prose and a title is written in prose, so the two
# agree on a word and disagree on its case constantly. Both terms below differ in
# case from the file, so neither can pass by accidentally matching verbatim.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha Caching' > /dev/null
work "$d" caching
lower="$R_OUT"
work "$d" CACHING
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}Alpha Caching${TAB}" "$lower" \
  "the lower-case term matches the capitalised title"
assert_eq "$lower" "$R_OUT" "and the upper-case term returns the very same row"

test_case "terms OR together, and a ticket two of them hit is still one row"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
ticket "$d" open v1/bug ACME-0002 beta 'Beta sharding' > /dev/null
ticket "$d" open v1/bug ACME-0003 gamma 'Gamma quiescence' > /dev/null
work "$d" caching
assert_eq "ACME-0001" "$(row_ids)" "one term, one ticket"
work "$d" sharding
assert_eq "ACME-0002" "$(row_ids)" \
  "the other term, the other ticket — the two hit disjoint tickets"
work "$d" caching sharding
assert_eq "ACME-0001 ACME-0002" "$(row_ids)" \
  "together they return the union, and still not the third ticket"
work "$d" caching alpha
assert_eq "ACME-0001" "$(row_ids)" \
  "and a ticket both terms hit contributes exactly one row, not one per term"

test_case "-- makes a hyphen-leading string a term instead of an option"
# The only way to search for something spelled like a flag, which candidates about
# deprecating one are. The bare run is the control: without the marker the same
# string is refused as an option, so the pass below is the marker working and not
# the parser being indifferent to hyphens.
d="$(newdir)"; make_tree "$d" ACME
f="$(ticket "$d" open v1/bug ACME-0001 alpha 'Alpha')"
printf 'Retire the -legacy flag this ticket is about.\n' >> "$f"
ticket "$d" open v1/bug ACME-0002 beta 'Beta' > /dev/null
work "$d" -legacy
assert_eq 2 "$R_STATUS" "without the marker the parser reads it as an option and refuses"
assert_eq "" "$R_OUT" "printing no rows"
assert_contains "$R_ERR" 'unknown option' "and naming what it refused"
work "$d" -- -legacy
assert_eq 0 "$R_STATUS" "behind the marker the identical string is a search term"
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}Alpha${TAB}" "$R_OUT" \
  "which returns the one ticket carrying it"
assert_eq "" "$R_ERR" "with no option complaint at all"

test_case "no terms at all is a usage error, never a request for the whole backlog"
# The dump this script used to print is the thing the query replaced, so the
# argument-less command line has to be refused rather than reinterpreted: a caller
# whose term list came out empty must be told, not handed every ticket in the tree
# and left to believe its candidate collided with all of them.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
ticket "$d" open v1/bug ACME-0002 beta 'Beta caching' > /dev/null
work "$d"
assert_eq 2 "$R_STATUS" "exits 2"
assert_eq "" "$R_OUT" "with nothing on stdout"
assert_contains "$R_ERR" 'usage: existing-work.sh' "and a usage line on stderr"
work "$d" caching
assert_eq "ACME-0001 ACME-0002" "$(row_ids)" \
  "on a tree that hands a real query two rows, so the empty stdout above is the refusal"

test_case "an empty term is refused too, because grep -F reads it as every file"
# An unset caller variable expands to nothing, and `grep -F -e ""` selects every
# line of every file. Refusing the empty string is what keeps a slipped `$term`
# from resurrecting the full-backlog dump under a command line that looks like a
# narrow query — the one failure mode a caller could not see in the output.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
ticket "$d" open v1/bug ACME-0002 beta 'Beta caching' > /dev/null
work "$d" ""
assert_eq 2 "$R_STATUS" "exits 2"
assert_eq "" "$R_OUT" "printing no rows at all, let alone every ticket in the tree"
assert_contains "$R_ERR" 'empty search term' "and saying which argument was wrong"
work "$d" caching ""
assert_eq 2 "$R_STATUS" "an empty term beside a real one is refused as well"
assert_eq "" "$R_OUT" "rather than the real term's rows standing in for a checked query"
work "$d" caching
assert_eq "ACME-0001 ACME-0002" "$(row_ids)" \
  "while the same tree answers the real term alone with both rows"

test_case "a tab inside a front-matter value is squashed, never allowed through"
# The failure this guard prevents is not a crash: a title holding a tab emits six
# fields, the sixth lands in `resolution`, and an open ticket reads to the drafter
# as one already decided against — the single distinction the column makes.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha "$(printf 'a\tb tenant caching')" > /dev/null
ticket "$d" archive v1/bug ACME-0002 beta 'Beta caching' 'status: done' \
  "$(printf 'resolution: "closed\tby hand"')" > /dev/null
work "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" "both records still hold exactly five fields"
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}a b tenant caching${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "the tab became one space, and the value is still legible"
assert_eq "ACME-0002${TAB}done${TAB}bug${TAB}Beta caching${TAB}closed by hand" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0002')" \
  "the same squash applies to the resolution column"

test_case "a CRLF ticket file does not smuggle a carriage return into a field"
d="$(newdir)"; make_tree "$d" ACME
mkdir -p "$d/.ai/sift/open/v1/bug"
printf -- '---\r\nid: ACME-0001\r\ntitle: Alpha\r\nstatus: open\r\ntype: bug\r\n' \
  > "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
printf -- 'milestone: v1\r\npriority: p2\r\neffort: m\r\ncreated: 2026-08-01\r\n' \
  >> "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
printf -- 'updated: 2026-08-01\r\n---\r\n\r\n# Alpha\r\n' \
  >> "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
work "$d" alpha
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(row_ids)" "the term found the CRLF ticket"
assert_eq "5" "$(tsv_widths)" "still five fields"
assert_eq 0 "$(printf '%s' "$R_OUT" | tr -cd '\r' | wc -c | tr -d ' ')" \
  "no carriage return reaches the answer, so a reader cannot mistake one for data"

# --- The output caps: what an answer costs, whatever the tree looks like -----

test_case "an answer past the row cap is capped, ranked, and still a sorted TSV"
# The tree the caps exist for: a project whose whole archive shares one subject.
# Thirty tickets carry `translation`, so a query naming that word overflows the
# default cap of 25 no matter how the rest of the command line is spelled — the
# answer has to be bounded by construction, not by how narrow the terms were.
#
# Three of the thirty carry a second distinctive word, so the two-term query
# ranks those three at two distinct terms against everyone else's one. That makes
# the survivor set decidable in advance and pins both halves of the rule at once:
# the three highest IDs in the tree survive on rank although twenty-seven lower
# IDs would sort ahead of them, and the twenty-two seats left go to the lowest IDs
# of the one-term group. The cut therefore falls inside a group whose members are
# all ranked alike, which is the only place the ascending-ID tie-break can be
# observed.
d="$(newdir)"; make_tree "$d" ACME
for ((i = 1; i <= 27; i++)); do
  ticket "$d" archive v1/bug "$(acme_id "$i")" "t$i" "Translation batch $i" \
    'status: done' 'resolution: "Closed as a duplicate"' > /dev/null
done
for ((i = 28; i <= 30; i++)); do
  ticket "$d" archive v1/bug "$(acme_id "$i")" "t$i" "Translation pluralization $i" \
    'status: done' 'resolution: "Closed as a duplicate"' > /dev/null
done
ticket "$d" open v1/bug ACME-0031 sigma 'Sharding alpha' > /dev/null
ticket "$d" open v1/bug ACME-0032 tau 'Sharding beta' > /dev/null
work "$d" translation pluralization
assert_eq 0 "$R_STATUS" "a capped answer is a successful answer, not an error"
assert_eq 25 "$(row_count)" \
  "exactly SIFT_MATCH_LIMIT rows reach stdout, not the thirty tickets that matched"
assert_eq "$(acme_ids 1 22) ACME-0028 ACME-0029 ACME-0030" "$(row_ids)" \
  "rank saves the three double-term tickets, the tie-break spends the rest on the lowest IDs, and the printed rows are still in ID order"
assert_eq "5" "$(tsv_widths)" "a capped row is the same five-field record as an uncapped one"
assert_eq "" "$(printf '%s\n' "$R_OUT" | grep -e '^ACME-0023' -e '^ACME-0027' -e '^ACME-0031')" \
  "and the answer holds neither a one-term ticket below the cut nor a ticket the terms never named"

test_case "the overflow notice names the count, the cut, and the way out"
# Asserted on the run above, so the notice is measured against a stdout that was
# really truncated. The caller cannot see the cut in the rows — twenty-five valid
# records look exactly like a complete answer — so the three facts below are the
# only thing standing between a capped answer and a false "no prior work".
assert_contains "$R_ERR" 'matched 30 tickets' \
  "how many tickets really matched, which is the number the rows do not show"
assert_contains "$R_ERR" 'showing the 25 best matches' "how many of them the caller is looking at"
assert_contains "$R_ERR" "narrow the terms to this candidate's distinguishing vocabulary" \
  "and the remedy, because the next move is another query and not a verdict"

test_case "a raised cap returns every matching row, so the cap was the only thing limiting"
# The positive control for the case above. Same tree, same terms, one number
# changed: without it a script that had stopped reading two-thirds of the archive
# would satisfy every assertion up there and call it a cap.
work_limit "$d" 100 translation pluralization
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 30 "$(row_count)" "all thirty matching tickets come back once the cap is out of the way"
assert_eq "$(acme_ids 1 30)" "$(row_ids)" \
  "the five the default cap dropped included, so that cut was the cap and not the query"
assert_eq "" "$R_ERR" "and no notice at all, because nothing was withheld"

test_case "a resolution past 200 characters is cut and marked; one at exactly 200 is not"
# The column cap, held at its boundary from both sides. A cut resolution that
# still reads as a complete sentence would be concluded from, so a row that was
# shortened has to say so, and a row that was not must not claim it was.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive v1/bug ACME-0001 long 'Long caching' 'status: done' \
  "resolution: \"$(fill 200 a)$(fill 50 b)\"" > /dev/null
ticket "$d" archive v1/bug ACME-0002 exact 'Exact caching' 'status: done' \
  "resolution: \"$(fill 200 c)\"" > /dev/null
work "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001 ACME-0002" "$(row_ids)" "both tickets are in the answer"
cut_res="$(row_col ACME-0001 5)"
kept_res="$(row_col ACME-0002 5)"
assert_ne "" "$cut_res" "the over-long ticket really has a resolution column to measure"
assert_eq 203 "${#cut_res}" "which is 200 characters plus the three-character marker"
assert_eq "$(fill 200 a)..." "$cut_res" \
  "the first 200 characters verbatim, and nothing of the 50 past the boundary"
assert_eq "$(fill 200 c)" "$kept_res" \
  "a resolution of exactly 200 characters is printed whole"
assert_not_contains "$kept_res" '...' \
  "with no marker, because a marker means 'the rest is in the file' and there is no rest"
assert_eq "5" "$(tsv_widths)" "and neither row grew a field"

test_case "a multibyte character sitting on the boundary is cut whole, not in half"
# The cut is spelled as a character slice rather than a byte one, and the
# difference only shows where a character straddles the boundary: the 200th
# character here is two bytes wide, so a byte-based cut would emit its lead byte
# alone and hand the reader a field that is not text any more. Run under a UTF-8
# locale because the slice follows the caller's locale — the harness runs cases
# under C by default, where the same fixture does halve the character.
if locale_available C.utf8; then
  d="$(newdir)"; make_tree "$d" ACME
  head199="$(fill 199 a)"
  ticket "$d" archive v1/bug ACME-0001 multibyte 'Multibyte caching' 'status: done' \
    "resolution: \"${head199}é$(fill 20 b)\"" > /dev/null
  # R_LOCALE is an input global read by run_cmd in tests/lib/harness.sh, so no
  # reader for it exists in this file. The reset below is load-bearing: without it
  # every case after this one would keep running under C.utf8.
  # shellcheck disable=SC2034
  R_LOCALE=C.utf8
  work "$d" caching
  # shellcheck disable=SC2034
  R_LOCALE=C
  assert_eq 0 "$R_STATUS" "exits 0"
  mb_res="$(row_col ACME-0001 5)"
  assert_ne "" "$mb_res" "the row is in the answer and carries a resolution to measure"
  assert_eq "${head199}é..." "$mb_res" \
    "199 plain characters, the two-byte 200th kept entire, then the marker"
  assert_eq 204 "$(printf '%s' "$mb_res" | wc -c | tr -d '[:space:]')" \
    "199 + 2 + 3 bytes: no lone continuation byte, so the field is still decodable text"
else
  skip "the 200-character cut across a multibyte boundary" \
    "no C.utf8 locale on this machine, and the cut follows the caller's locale"
fi

test_case "a cap that is not a positive integer is refused before anything is printed"
# The one number a caller can get wrong, and both wrong spellings fail alike on
# purpose. `abc` is the typo; `0` is the more dangerous one, because a cap of zero
# is syntactically fine and answers every query with silence — which reads to a
# drafter exactly like "nothing similar has ever been filed".
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
ticket "$d" open v1/bug ACME-0002 beta 'Beta caching' > /dev/null
for bad in abc 0; do
  work_limit "$d" "$bad" caching
  assert_eq 2 "$R_STATUS" "SIFT_MATCH_LIMIT=$bad exits 2, the setup error"
  assert_contains "$R_ERR" 'SIFT_MATCH_LIMIT must be a positive integer' \
    "naming the variable and the shape it wanted"
  assert_eq "" "$R_OUT" "with nothing on stdout, so no half-answer can stand in for a checked query"
done
work_limit "$d" 1 caching
assert_eq 0 "$R_STATUS" "a cap of one is a legal cap"
assert_eq "ACME-0001" "$(row_ids)" \
  "and returns its one row from the same tree, so the two empty stdouts above are the refusal"

test_case "asking the backlog decides nothing on disk"
# Both exits are measured, because the refusal path is the one that could still
# leave something behind: it parses arguments, resolves the tree, and only then
# gives up.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha caching' > /dev/null
before="$(tree_digest "$d")"
work "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(row_ids)" "having really read the tree"
assert_eq "$before" "$(tree_digest "$d")" "the tree is byte-identical afterwards"
work "$d"
assert_eq 2 "$R_STATUS" "and the term-less form exits 2"
assert_eq "$before" "$(tree_digest "$d")" "leaving the same tree behind, byte for byte"

# =============================================================================
# reserve-ids.sh — the allocator, and the ID grammar it shares with sift-drain
# =============================================================================

# --- The ID rule, held once per skill: what a well-formed ticket ID is -------

# prime_ids <root> <count> — the IDs sift-prime hands its drafting agents.
# reserve-ids.sh is the only allocator in a priming run, so every ID that ever
# reaches a ticket file was printed by this command.
#
# Every caller reads it through `$( )`, so run_cmd's R_STATUS is set in the
# substitution's subshell and dies there: an `assert_eq 0 "$R_STATUS"` after one of
# these calls is silently reading whatever the previous command in the parent shell
# left behind. The status goes through a file, which does escape, and is read back
# by prime_status.
PRIME_STATUS_FILE="$TMPROOT/prime-status"
prime_ids() {
  run_cmd "$1" env SIFT_ROOT="$1" "$RESERVE" "$2"
  printf '%s\n' "$R_STATUS" > "$PRIME_STATUS_FILE"
  printf '%s\n' "$R_OUT" | LC_ALL=C sort
}

# prime_status — the exit status of the most recent prime_ids call.
prime_status() { cat "$PRIME_STATUS_FILE"; }

# drain_id_accepts <root> <ID…> — every candidate drain-log.sh's require_ticket_id
# lets past. Driven through `dispatch`, because a ticket argument is how an ID
# reaches that check through a real command line. The run log is removed after
# each probe so every one meets the same lazily-created file.
drain_id_accepts() {
  local root="$1"; shift
  local id
  for id in "$@"; do
    run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch "$id"
    case "$R_ERR" in
      *'not a ticket ID'*) ;;
      *) printf '%s\n' "$id" ;;
    esac
    rm -f "$root/.ai/sift/RUNLOG.md"
  done | LC_ALL=C sort
}

test_case "every ID sift-prime allocates is one sift-drain will log (SFT-0042)"
# The rule both skills hold a copy of: what a well-formed ticket ID is.
# reserve-ids.sh spells it as it WRITES — a prefix, a hyphen and a minimum-width
# four-digit number — and drain-log.sh's require_ticket_id spells it as it READS,
# and neither directory may source a file from the other. A divergence is
# invisible until a tree is already inconsistent: a batch prime allocated would
# be refused by the drain that has to dispatch it, and the run log would carry no
# row for work that exists on disk.
#
# Both tree states the width rule turns on are measured, because the widening
# past 9999 is exactly where a reader spelling the digits as `{4}` stops agreeing
# with a writer whose `%04d` is a minimum: an empty tree, and a tree whose
# high-water mark is already four digits wide.
d="$(newdir)"; make_tree "$d" ACME
fresh="$(prime_ids "$d" 3)"
assert_eq 0 "$(prime_status)" "the allocator exits 0 on a cold tree"
assert_eq "$(printf '%s\n' ACME-0001 ACME-0002 ACME-0003)" "$fresh" \
  "and opens the numbering at four digits"
assert_eq "$fresh" "$(drain_id_accepts "$d" $fresh)" \
  "the drain logs every one of them"

d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-9999 alpha 'Alpha' > /dev/null
wide="$(prime_ids "$d" 2)"
assert_eq "$(printf '%s\n' ACME-10000 ACME-10001)" "$wide" \
  "past 9999 the allocator widens the number rather than truncating it"
assert_eq "$wide" "$(drain_id_accepts "$d" $wide)" \
  "and the drain logs the wider IDs too, so %04d is a minimum width on both sides"

test_case "the shapes the allocator never emits are the shapes the drain refuses"
# The negative control for the agreement above. Without it a drain that had
# stopped checking anything at all would accept every allocated ID and report
# perfect agreement, which is the vacuous pass SFT-0010 was about. One list
# carries every shape the rule turns on and none of them is a shape reserve-ids.sh
# can produce — too few digits, a bare prefix, an empty tail, a non-digit tail,
# glue on the left edge, a second hyphenated group, the wrong case, a
# hyphen-leading argument and the `--` marker standing in an ID position.
d="$(newdir)"; make_tree "$d" ACME
malformed=(
  ACME-000         # three digits, one short of the floor
  ACME             # the bare prefix, with no hyphen and no number
  ACME-            # the prefix and a hyphen, with an empty tail
  ACME-0001x       # a non-digit tail, which is also the right-edge glue case
  XACME-0002       # glued to a longer token on the left edge
  ACME-0001-0002   # a second hyphenated group after a well-formed one
  acme-0001        # the right shape in the wrong case
  -ACME-0001       # hyphen-leading, the claim the skill's `--` grammar rests on
)
assert_eq "" "$(drain_id_accepts "$d" "${malformed[@]}")" \
  "the drain refuses every one of them by name"
allocated="$(prime_ids "$d" 20)"
overlap=""
for id in "${malformed[@]}"; do
  case "$NL$allocated$NL" in
    *"$NL$id$NL"*) overlap="$overlap $id" ;;
  esac
done
assert_eq "" "$overlap" \
  "and none of them is a string the allocator could have handed out"
assert_no_file "$d/.ai/sift/RUNLOG.md" "no refusal created a run log"

# --- The premise both copies of the ID rule rest on: one tree, one prefix ----

# drain_id_accepts_as <root> <prefix> <ID…> — the drain probe with the prefix
# forced through the environment instead of resolved from the tree. Both skills
# spell the prefix as `$PREFIX`, so "the ID prime allocates is the ID drain logs"
# is only ever true of skills that resolved the SAME prefix. This is how that
# premise is broken on purpose.
drain_id_accepts_as() {
  local root="$1" pfx="$2"; shift 2
  local id
  for id in "$@"; do
    run_cmd "$root" env SIFT_ROOT="$root" SIFT_PREFIX="$pfx" \
      "$DRAIN/drain-log.sh" dispatch "$id"
    case "$R_ERR" in
      *'not a ticket ID'*) ;;
      *) printf '%s\n' "$id" ;;
    esac
    rm -f "$root/.ai/sift/RUNLOG.md"
  done | LC_ALL=C sort
}

test_case "the two skills read one prefix out of one tree, however the config states it"
# The agreement above was measured on a tree whose config says `prefix: ACME` and
# nothing else. The prefix is itself resolved by a block each skill holds its own
# copy of, so the shapes can be byte-identical and the skills still disagree about
# which strings are IDs — and that disagreement is the one that reaches a real
# tree, because a config is written by hand and read by both skills.
#
# One ID pair is enough per scenario: with a resolved prefix of ACME, ACME-0001
# is an ID and ZULU-0001 is not, and swapping the answer is exactly what a drifted
# resolution does.
d="$(newdir)"; make_tree "$d" ACME
# Quoted, comment-trailed, and stated twice: three ways a hand-edited config goes
# ragged at once. `head -n 1` decides, so the first line wins on both skills or
# neither.
printf 'prefix: "ACME"   # the ticket prefix\nprefix: ZULU\n' \
  > "$d/.ai/sift/config/config.yaml"
assert_eq "ACME-0001" "$(prime_ids "$d" 1)" \
  "the allocator reads ACME past the quotes, the comment and the second line"
assert_eq "ACME-0001" "$(drain_id_accepts "$d" ACME-0001 ZULU-0001)" \
  "and the run log reads the same one, not the line below it"

d="$(newdir)"; make_tree "$d" ACME
rm "$d/.ai/sift/config/config.yaml"
ticket "$d" open v1/bug ZULU-0001 alpha 'Alpha' > /dev/null
assert_eq "ZULU-0002" "$(prime_ids "$d" 1)" \
  "with no config at all the allocator infers the prefix from the ticket filenames"
assert_eq "ZULU-0001" "$(drain_id_accepts "$d" ACME-0001 ZULU-0001)" \
  "and the run log infers the same one, so the inference is not a per-skill guess"

d="$(newdir)"; make_tree "$d" ACME
rm "$d/.ai/sift/config/config.yaml"
before="$(tree_digest "$d")"
run_cmd "$d" env SIFT_ROOT="$d" "$RESERVE" 1
p_status="$R_STATUS"; p_err="$R_ERR"
run_cmd "$d" env SIFT_ROOT="$d" "$DRAIN/drain-log.sh" dispatch ACME-0001
assert_eq 2 "$p_status" "with nothing to resolve a prefix from, the allocator exits 2"
assert_eq "$p_status" "$R_STATUS" "and the drain exits the same way"
assert_eq "$p_err" "$R_ERR" "with byte-identical stderr, the hint included"
assert_contains "$p_err" 'cannot determine the ticket prefix' \
  "so neither skill falls back to a prefix of its own and calls IDs by it"
assert_no_file "$d/.ai/sift/RUNLOG.md" "no run log was created"
assert_eq "$before" "$(tree_digest "$d")" "and neither refusal wrote anything"

test_case "an environment that hands one skill a different prefix is where the agreement stops"
# The positive control for the three scenarios above, and the real-world shape of
# the failure the record names: SIFT_PREFIX is per invocation, so an orchestrator
# that exports it for one skill and not the other gets two skills that classify the
# same string differently — the drain writing a run-log row for a ZULU ticket that
# prime would never have allocated, and `report` pairing it against nothing.
# Without this control, a probe that had stopped depending on the resolved prefix
# would report agreement on every tree and prove nothing at all.
d="$(newdir)"; make_tree "$d" ACME
got_prime="$(prime_ids "$d" 1)"
got_drain="$(drain_id_accepts_as "$d" ZULU ACME-0001 ZULU-0001)"
assert_eq "ACME-0001" "$got_prime" "the allocator resolves ACME out of the tree"
assert_eq "ZULU-0001" "$got_drain" "the drain resolves ZULU out of its environment"
assert_ne "$got_prime" "$got_drain" \
  "the two sets differ, so the agreements above are measurements and not tautologies"
assert_eq "$got_prime" "$(drain_id_accepts_as "$d" ACME ACME-0001 ZULU-0001)" \
  "handed the same prefix the allocator resolved, the drain classifies alike again"

summary
