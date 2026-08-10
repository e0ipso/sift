#!/usr/bin/env bash
# roadmap-append.sh — append one ticket row to a wave of .ai/sift/ROADMAP.md.
#
# The only sift-prime script that writes. It adds exactly one row and creates the
# "## Wave <n>" section when it is missing; it never renumbers an existing row,
# never rewrites a row it did not add, and never reorders sections. README rule 9
# makes ticket creation and roadmap slotting one change, so this is the write half
# of creating a ticket — run it in the same change as the ticket file.
#
# New sections are appended at the end of the file. Waves are created in ascending
# order by the caller; nothing here inserts Wave 3 between Wave 2 and Wave 4.
#
# Usage:
#   scripts/roadmap-append.sh <wave> <ID> <title> <needs>
#
#   <wave>   whole number >= 1
#   <ID>     <PREFIX>-NNNN, not already the ticket cell of a roadmap row (being
#            named as another row's blocker or in its title is not a row)
#   <title>  the ticket title, no "|" (it would break the table) and no control
#            character such as a tab (it would break the tab-separated read)
#   <needs>  space- or comma-separated blocker IDs; pass "" for none
#
# Example:
#   scripts/roadmap-append.sh 1 SIFT-0007 "Cache tenant lookups" "SIFT-0003"
#
# Exit codes: 0 appended | 1 invalid argument or duplicate ID | 2 setup error (from lib.sh).

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

USAGE='usage: roadmap-append.sh <wave> <ID> <title> <needs>, e.g. roadmap-append.sh 1 '"$PREFIX"'-0007 "Cache tenant lookups" ""'

die() {
  echo "error: $1" >&2
  echo "hint: $USAGE" >&2
  exit 1
}

# --- Arguments --------------------------------------------------------------
# Exactly four, because <needs> is empty far more often than it is set: making it
# optional would let a dropped title silently land in the needs column.
[ "$#" -eq 4 ] || die "roadmap-append.sh takes exactly 4 arguments, got $#"

WAVE="$1"
ID="$2"
TITLE="$3"
NEEDS="$4"

case "$WAVE" in
  '' | *[!0-9]*) die "wave must be a whole number, got: $WAVE" ;;
esac
# Base 10 forced: bash reads a leading-zero literal as octal, where 08 is invalid.
WAVE=$((10#$WAVE))
[ "$WAVE" -ge 1 ] || die "wave must be at least 1, got: $WAVE"

case "$ID" in
  "$PREFIX"-[0-9][0-9][0-9][0-9]*) ;;
  *) die "ticket ID must look like $PREFIX-NNNN, got: $ID" ;;
esac
case "${ID#"$PREFIX"-}" in
  *[!0-9]*) die "ticket ID must look like $PREFIX-NNNN, got: $ID" ;;
esac

[ -n "$TITLE" ] || die "title must not be empty"

# A "|" or a newline in a cell would silently mangle the table, and a mangled row
# is a row sift-drain cannot parse. Refuse rather than write it. Any other control
# character is refused for the same reason one step downstream: sift-drain hands
# roadmap rows out as tab-separated fields, so a literal tab inside a cell adds a
# field and shifts every column after it.
#
# The check has to hold all the way through the awk hop below, which is why the
# values reach awk through the environment and ENVIRON rather than through -v:
# awk's -v runs ANSI escape processing on its argument, so a two-character "\n"
# that passed this check would become a real newline inside awk and write the
# mangled multi-line row this check exists to refuse. ENVIRON does no such
# processing, so what is validated here is what lands in the file.
for cell in "$TITLE" "$NEEDS"; do
  case "$cell" in
    *'|'*) die "title and needs must not contain '|', got: $cell" ;;
    *$'\n'*) die "title and needs must not contain a newline" ;;
    *[[:cntrl:]]*) die "title and needs must not contain a control character (a tab included), got: $cell" ;;
  esac
done

# --- What a roadmap row is ---------------------------------------------------
# One definition, held in exactly one place on this card and read by both the
# duplicate check and the append hop below, so the two cannot disagree about
# what they are looking at: a roadmap row is a markdown table line, and within
# it the FIRST cell holding a whole-token <PREFIX>-NNNN.
#
# sift-drain's lib.sh roadmap_rows states the same rule for the read side. That
# second copy is a standing decision, not an oversight, and it is recorded in
# AGENTS.md under "Duplication between cards" (SFT-0038): the cards install
# independently and neither directory may source a file from the other, so the
# rule is written out once per card and a drift between them is caught by a test
# rather than by a tree that is already wrong. The test is "the reader and the
# writer classify every cell of one table alike" in
# tests/scripts/prime-backlog.test.sh — change this rule and the drain reader in
# the same commit, and run it to prove they still agree.
#
# The digit run is greedy rather than exactly four so a five-digit ID reads out
# whole: with a fixed four, ACME-00011 would surrender the ID ACME-0001 it does
# not have (SFT-0025). Greedy also supplies the right-hand whole-token guard for
# free, because a run of digits cannot stop mid-number.
ROW_ID_PAT="$PREFIX-[0-9][0-9][0-9][0-9][0-9]*"

# The ID a cell holds, or "" when it holds none. Whole-token on the left so a
# suffix of a longer word is not an ID, and [[:alnum:]] rather than a spelled
# range so a UTF-8 locale cannot re-collate the set.
#
# An awk fragment prepended to both programs below rather than a copy pasted
# into each: two copies inside one file is the same bug as two copies across two
# cards, at shorter range, and it is the bug this file had — the append hop
# selected its cell on the bare pattern and so counted a glued XACME-0001 cell
# as a row the duplicate guard beside it never saw. Being a single-quoted shell
# string, it must stay free of an apostrophe, a dollar sign and a backslash;
# `pat` is the calling program's BEGIN-block global.
ROW_CELL_ID_AWK='
    function cell_id(s,   id, before) {
      while (match(s, pat)) {
        id = substr(s, RSTART, RLENGTH)
        before = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        if (before !~ /[[:alnum:]]/) return id
        s = substr(s, RSTART + RLENGTH)
      }
      return ""
    }
'

# --- Duplicate ID -----------------------------------------------------------

# Rule 2 makes IDs immutable and never reused, so a second row for an ID already
# in the file means the caller lost track of what it wrote. Fail loudly: silently
# skipping would leave the caller believing a row exists in a wave where it does
# not.
#
# "Already in the file" means a ROW, not a mention, by the rule above: only
# markdown table lines count, and within a line only the FIRST cell holding an ID
# is the ticket cell. An ID named in a Needs cell, quoted in a Title or written
# in the prose around the table belongs to somebody else's row and must never
# block its own. A struck row does count for its own ID — rule 2 makes an ID
# unreusable whether or not the work finished, and ~~ delimiters are not
# identifier characters, so it falls out of the same whole-token rule rather than
# needing a case of its own.
#
# awk, not a second grep: one parse of the table, in the same shape and through
# the same pattern and cell_id as the append hop below, is what keeps this check
# from drifting away from the thing it is guarding.
if ROW_ID_PAT="$ROW_ID_PAT" RA_ID="$ID" awk -F'|' "$ROW_CELL_ID_AWK"'
    BEGIN { pat = ENVIRON["ROW_ID_PAT"]; want = ENVIRON["RA_ID"] }
    !/^[[:space:]]*\|/ { next }
    NF < 3 { next }
    {
      # The ticket cell is the FIRST cell that HOLDS an ID, not the first the
      # pattern matches somewhere inside. Selecting on the bare pattern let a
      # mistyped XACME-0001 to the left shadow the real ticket cell, so this
      # guard stopped seeing a row the sift-drain reader reports and appended the
      # duplicate roadmap-check.sh then blames on the malformed cell nobody was
      # looking at (SFT-0031). Still the first such cell and no other: a match
      # anywhere on the line would make a Needs mention a row again (SFT-0022).
      rid = ""
      for (i = 1; i <= NF; i++) { rid = cell_id($i); if (rid != "") break }
      if (rid == want) { found = 1; exit }
    }
    END { exit (found ? 0 : 1) }
  ' "$ROADMAP"; then
  echo "error: $ID already has a row in $ROADMAP" >&2
  echo "hint: IDs are never reused and a ticket gets exactly one row (README rule 9)" >&2
  exit 1
fi

TMP="$ROADMAP.tmp"
# The write always goes through a temporary file and a mv, never through in-place
# editing: the GNU and BSD forms of that flag disagree on the backup-suffix
# argument. The .tmp suffix cannot match the $PREFIX-*.md glob, so a concurrent
# agent's find never sees a half-written roadmap.
trap 'rm -f "$TMP"' EXIT

WAVE_RE="^##[[:space:]]*[Ww]ave[[:space:]]+$WAVE([^0-9]|\$)"

if command grep -qE "$WAVE_RE" "$ROADMAP"; then
  # --- Case A: the wave exists — insert after its last table row -------------
  # Every input line is printed verbatim, so a diff of before/after shows only
  # additions. Lines trailing the section's last table row (blank lines, prose)
  # are buffered and re-emitted after the new row, keeping the table contiguous.
  # Every string reaches awk through the environment and ENVIRON, never through
  # -v: -v runs ANSI escape processing on its argument, so a title containing the
  # two characters "\" and "t" would arrive inside awk as a real tab and a "\n"
  # as a real newline — after the validation above had already passed them. The
  # new-wave path below writes the same values with printf %s, so keeping this
  # path escape-free is also what makes the two paths byte-identical.
  RA_PAT="$ROW_ID_PAT" \
  RA_WAVE_RE="$WAVE_RE" \
  RA_ROW_ID="$ID" \
  RA_ROW_TITLE="$TITLE" \
  RA_ROW_NEEDS="$NEEDS" \
  awk -F'|' "$ROW_CELL_ID_AWK"'
    BEGIN {
      pat       = ENVIRON["RA_PAT"]
      wave_re   = ENVIRON["RA_WAVE_RE"]
      row_id    = ENVIRON["RA_ROW_ID"]
      row_title = ENVIRON["RA_ROW_TITLE"]
      row_needs = ENVIRON["RA_ROW_NEEDS"]
    }
    # [[:space:]], never a hand-rolled space-and-backslash-t class: POSIX leaves
    # a backslash inside a bracket expression undefined, so a strict awk reads
    # that set as {space, backslash, t} and eats a leading "t" in a title.
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function flush_buf(   i) { for (i = 1; i <= nbuf; i++) print buf[i]; nbuf = 0 }
    function emit_row(   num) {
      # Continue the wave numbering without ever touching an existing cell: one
      # past the highest "#" seen, and at least one past the number of rows, so a
      # section with a hand-deleted row cannot produce a duplicate "#".
      num = nrows
      if (maxnum > num) num = maxnum
      if (!sawtable) {
        print "| # | Ticket | Title | Needs |"
        print "|---|---|---|---|"
      }
      printf "| %d | %s | %s | %s |\n", num + 1, row_id, row_title, row_needs
      done = 1
    }
    /^##[[:space:]]/ {
      if (insec) { emit_row(); flush_buf(); insec = 0 }
      if ($0 ~ wave_re) insec = 1
      print
      next
    }
    insec && /^[[:space:]]*\|/ {
      flush_buf()
      print
      sawtable = 1
      # The same cell rule as the duplicate guard above, through the same
      # cell_id: a cell whose ID is glued to a longer word holds no ID, so the
      # line it sits on is not a row and is not counted as one here either.
      # Selecting on the bare pattern counted it, and then read its "#" into
      # maxnum, so a table holding one real row beside one mistyped line
      # numbered the next row 3 while the guard above saw a single row — the
      # same divergence as between the cards, inside one file.
      cell = 0
      for (i = 1; i <= NF; i++) if (cell_id($i) != "") { cell = i; break }
      if (cell) {
        nrows++
        # Same cell convention as sift-drain roadmap_rows: the "#" column is $2
        # whenever the ticket cell is further right.
        if (cell > 2) {
          o = trim($2)
          if (o ~ /^[0-9]+$/ && o + 0 > maxnum) maxnum = o + 0
        }
      }
      next
    }
    insec { buf[++nbuf] = $0; next }
    { print }
    END {
      if (insec) { emit_row(); flush_buf() }
      if (!done) exit 3
    }
  ' "$ROADMAP" > "$TMP" || {
    echo "error: failed to build the updated roadmap for wave $WAVE" >&2
    exit 1
  }
else
  # --- Case B: the wave is new — append a whole section at EOF ---------------
  # A file not ending in a newline would otherwise glue the heading onto its last
  # line, and a file already ending in a blank line needs no second one.
  NEEDS_NEWLINE=0
  [ -n "$(tail -c 1 "$ROADMAP")" ] && NEEDS_NEWLINE=1
  NEEDS_BLANK=0
  [ -n "$(tail -n 1 "$ROADMAP")" ] && NEEDS_BLANK=1

  {
    cat "$ROADMAP" || exit 1
    [ "$NEEDS_NEWLINE" -eq 1 ] && printf '\n'
    [ "$NEEDS_BLANK" -eq 1 ] && printf '\n'
    printf '## Wave %d\n\n' "$WAVE"
    printf '| # | Ticket | Title | Needs |\n'
    printf '|---|---|---|---|\n'
    printf '| 1 | %s | %s | %s |\n' "$ID" "$TITLE" "$NEEDS"
  } > "$TMP" || {
    echo "error: failed to build the updated roadmap for wave $WAVE" >&2
    exit 1
  }
fi

mv "$TMP" "$ROADMAP" || {
  echo "error: failed to move $TMP into place" >&2
  exit 1
}
trap - EXIT

echo "appended: wave $WAVE / $ID / $TITLE"
exit 0
