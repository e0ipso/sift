#!/usr/bin/env bash
# existing-work.sh and reserve-ids.sh — what priming reads, and what it hands out
# (SFT-0019).
#
# One priming pass reads twice and writes nothing of its own: `existing-work.sh`
# hands the drafter the whole backlog as a dedupe corpus, and `reserve-ids.sh`
# hands each drafting agent the one ID it may use. They are pinned together
# because they are the two reads that decide what a batch becomes — what is
# already filed, and what the new work is called.
#
# The corpus stakes everything on one promise: a tab must never appear where a tab
# means "next field", so the reader squashes one out of a front-matter value
# rather than letting its five-field TSV shift the `resolution` column.
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

work() { run_cmd "$1" env SIFT_ROOT="$1" "$WORK"; }

# tsv_widths — every distinct field count across R_OUT.
tsv_widths() {
  printf '%s\n' "$R_OUT" | awk -F'\t' '{ print NF }' | LC_ALL=C sort -u |
    tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# =============================================================================
# existing-work.sh — the dedupe corpus
# =============================================================================

test_case "an empty backlog prints nothing and succeeds"
# A fresh sift-init tree is the first state a priming pass meets, and "nothing
# filed yet" must not read as an error, nor as one blank record.
d="$(newdir)"; make_tree "$d" ACME
work "$d"
assert_eq 0 "$R_STATUS" "exit 0 on a tree with no tickets"
assert_eq "" "$R_OUT" "and not one byte on stdout"
assert_eq "" "$R_ERR" "nor a complaint about the empty archive/"

test_case "every ticket in either bucket is one five-field record"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0002 beta 'Beta' > /dev/null
ticket "$d" open v1/feature ACME-0010 iota 'Iota' 'type: feature' 'status: blocked' > /dev/null
ticket "$d" archive v1/bug ACME-0001 alpha 'Alpha' \
  'status: done' 'resolution: "Fixed upstream"' > /dev/null
ticket "$d" archive v2/docs ACME-0003 gamma 'Gamma' \
  'status: wontfix' 'type: docs' 'resolution: "Superseded by ACME-0001"' > /dev/null
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" \
  "id, status, type, title, resolution — the same count on every line, open and archived"

test_case "the records are sorted by ID, whatever the tree looks like"
# The corpus is read by a drafter checking "has this already been filed", so the
# order has to come from the ID and not from the order find happened to walk two
# buckets and four milestone folders.
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0010" \
  "$(printf '%s\n' "$R_OUT" | cut -f 1 | tr '\n' ' ' | sed 's/[[:space:]]*$//')" \
  "zero-padding makes the plain sort an ID sort, past the ninth ticket"

test_case "resolution is the column that separates filed from decided against"
assert_eq "ACME-0001${TAB}done${TAB}bug${TAB}Alpha${TAB}Fixed upstream" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "an archived ticket carries its closing line, unquoted"
assert_eq "ACME-0002${TAB}open${TAB}bug${TAB}Beta${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0002')" \
  "an open ticket leaves it empty rather than omitting the field"
assert_eq "ACME-0003${TAB}wontfix${TAB}docs${TAB}Gamma${TAB}Superseded by ACME-0001" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0003')" \
  "and a wontfix reads as decided against, which is the distinction it exists for"

test_case "a tab inside a front-matter value is squashed, never allowed through"
# The failure this guard prevents is not a crash: a title holding a tab emits six
# fields, the sixth lands in `resolution`, and an open ticket reads to the drafter
# as one already decided against — the single distinction the column makes.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha "$(printf 'a\tb tenant caching')" > /dev/null
ticket "$d" archive v1/bug ACME-0002 beta 'Beta' 'status: done' \
  "$(printf 'resolution: "closed\tby hand"')" > /dev/null
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" "both records still hold exactly five fields"
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}a b tenant caching${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "the tab became one space, and the value is still legible"
assert_eq "ACME-0002${TAB}done${TAB}bug${TAB}Beta${TAB}closed by hand" \
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
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" "still five fields"
assert_eq 0 "$(printf '%s' "$R_OUT" | tr -cd '\r' | wc -c | tr -d ' ')" \
  "no carriage return reaches the corpus, so a reader cannot mistake one for data"

test_case "reading the backlog decides nothing on disk"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha' > /dev/null
before="$(tree_digest "$d")"
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" "the tree is byte-identical afterwards"

# =============================================================================
# reserve-ids.sh — the allocator, and the ID grammar it shares with sift-drain
# =============================================================================

# --- The ID rule, held once per skill: what a well-formed ticket ID is -------

# prime_ids <root> <count> — the IDs sift-prime hands its drafting agents.
# reserve-ids.sh is the only allocator in a priming run, so every ID that ever
# reaches a ticket file was printed by this command.
prime_ids() {
  run_cmd "$1" env SIFT_ROOT="$1" "$RESERVE" "$2"
  printf '%s\n' "$R_OUT" | LC_ALL=C sort
}

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
assert_eq 0 "$R_STATUS" "the allocator exits 0 on a cold tree"
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
