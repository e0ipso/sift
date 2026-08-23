#!/usr/bin/env bash
# Shared helpers for the sift-drain scripts. Sourced, never executed directly.
#
# Provides:
#   ROOT / SIFT / ROADMAP / PREFIX  — resolved absolute paths and the ticket prefix
#   roadmap_rows                    — TSV of every roadmap ticket row
#   ticket_file <ID>                — absolute path of a ticket file, or empty
#   fm_value <file> <key>           — one front-matter value
#   fm_labels <file>                — one label per line from labels: [...]
#   SIFT_LABEL_RE                   — regex a well-formed kebab label matches
#   label_is_kebab <label>          — true when one label matches SIFT_LABEL_RE
#   ticket_cluster <file>           — the optional `cluster` value, or empty
#   effort_weight <effort>          — the dispatch weight of one effort value
#   ticket_search_dirs [--open]     — .ai/sift/open [and archive/]
#
# Overrides:
#   SIFT_ROOT    project root (default: nearest ancestor of $PWD with .ai/sift/ROADMAP.md)
#   SIFT_PREFIX  ticket prefix (default: .ai/sift/config/config.yaml, then inferred)

# --- Project root -----------------------------------------------------------
# Walk upward from $PWD for a directory holding `.ai/sift/`. Nested `.git`
# folders are deliberately ignored, so running from a subproject of a monorepo
# still resolves to the nearest parent sift tree. The `.ai/sift/` DIRECTORY is
# the marker, not ROADMAP.md — an initialized tree missing its roadmap must
# report that specifically rather than looking like "no project here".
_sift_find_root() {
  local dir parent
  dir="$PWD"
  while true; do
    [ -d "$dir/.ai/sift" ] && { printf '%s\n' "$dir"; return 0; }
    parent="$(dirname "$dir")"
    [ "$parent" = "$dir" ] && return 1   # reached the filesystem root
    dir="$parent"
  done
}

if [ -n "${SIFT_ROOT:-}" ]; then
  ROOT="$(cd "$SIFT_ROOT" 2>/dev/null && pwd)" || {
    echo "error: SIFT_ROOT is not a readable directory: $SIFT_ROOT" >&2
    exit 2
  }
  if [ ! -d "$ROOT/.ai/sift" ]; then
    echo "error: no .ai/sift/ directory under SIFT_ROOT=$ROOT" >&2
    exit 2
  fi
else
  ROOT="$(_sift_find_root)" || {
    echo "error: no .ai/sift/ directory found at or above $PWD" >&2
    echo "hint: run from inside the project, or set SIFT_ROOT=/path/to/project" >&2
    exit 2
  }
fi

SIFT="$ROOT/.ai/sift"
ROADMAP="$SIFT/ROADMAP.md"

if [ ! -f "$ROADMAP" ]; then
  echo "error: sift tree at $SIFT has no ROADMAP.md" >&2
  echo "hint: every ticket needs a roadmap row — create ROADMAP.md first" >&2
  exit 2
fi

# --- Ticket prefix ----------------------------------------------------------
PREFIX="${SIFT_PREFIX:-}"
if [ -z "$PREFIX" ] && [ -f "$SIFT/config/config.yaml" ]; then
  PREFIX="$(sed -n 's/^prefix:[[:space:]]*["'\'']\{0,1\}\([A-Za-z0-9_]\{1,\}\).*/\1/p' \
    "$SIFT/config/config.yaml" | head -n 1)"
fi
if [ -z "$PREFIX" ]; then
  # Fall back to the most common prefix among existing ticket filenames.
  PREFIX="$(find "$SIFT/open" "$SIFT/archive" -name '*--*.md' 2>/dev/null |
    sed 's#.*/##' |
    sed -n 's/^\([A-Z][A-Z0-9]*\)-[0-9][0-9][0-9][0-9].*/\1/p' |
    sort | uniq -c | sort -rn | head -n 1 | awk '{ print $2 }')"
fi
if [ -z "$PREFIX" ]; then
  echo "error: cannot determine the ticket prefix" >&2
  echo "hint: set 'prefix:' in $SIFT/config/config.yaml, or export SIFT_PREFIX" >&2
  exit 2
fi

# --- Roadmap parsing --------------------------------------------------------
# Print one TSV line per roadmap ticket row:
#   wave <TAB> order <TAB> ID <TAB> struck(0|1) <TAB> title
#
# Only markdown table rows count, and only the FIRST cell holding a whole-token
# ID is the ticket cell — so ID mentions in a Title or Needs column never
# register as rows, and neither does a cell whose ID is glued to a longer word.
# Rows under "## Wave <n>" headings are grouped by wave; a roadmap with no wave
# headings is reported as a single wave 1.
roadmap_rows() {
  awk -F'|' -v prefix="$PREFIX" '
    # [[:space:]], not [ \t]: POSIX leaves a backslash inside a bracket
    # expression undefined, so a strict awk reads [ \t] as {space, \, t} and
    # eats the leading "t" of a title like "tenant caching".
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    # No apostrophe below: this awk program is one single-quoted shell string,
    # so an "it is" spelled with one would close it mid-comment.
    #
    # The digit run is greedy rather than exactly four, because the ID handed
    # back below is substr($cell, RSTART, RLENGTH) — as narrow as the pattern
    # that matched. With a fixed four, ACME-00011 surrenders the ID ACME-0001,
    # which belongs to a different ticket or to none: the reader invents a
    # stale row and never checks the real one. %04d is a minimum width (see
    # reserve-ids.sh in sift-prime), so IDs widen past 9999 rather than
    # stopping there. Greedy also supplies the right-hand whole-token guard
    # for free: a run of digits cannot stop mid-number, so ACME-0001 and
    # ACME-00011 stay distinct rows in either order. This is byte-for-byte the
    # ROW_ID_PAT that roadmap-append.sh in sift-prime matches a ticket cell
    # with, and that second copy is a recorded decision rather than an accident:
    # AGENTS.md under "Duplication between skills" (SFT-0038) holds that the skills
    # install independently and neither directory may source a file from the
    # other, so the rule is written out once per skill and a drift between them is
    # caught by a test rather than by a tree that is already wrong. The test is
    # "the reader and the writer classify every cell of one table alike" in
    # tests/scripts/prime-backlog.test.sh, which drives one fixture table through
    # both skills — change this rule and roadmap-append.sh in the same commit, and
    # run that test to prove they still agree.
    BEGIN { pat = prefix "-[0-9][0-9][0-9][0-9][0-9]*" }
    # The ID a cell holds, or "" when it holds none. Whole-token on the left so a
    # suffix of a longer word is not an ID, and [[:alnum:]] rather than a spelled
    # range so a UTF-8 locale cannot re-collate the set; whole-token on the right
    # comes free from the greedy digit run, which cannot stop mid-number.
    #
    # A match starting at the very first character has no preceding character,
    # and substr(cs, 0, 1) is not one either — awk returns the empty string from
    # a start index below 1 rather than erroring, which would read as "a
    # character that is not alphanumeric" only by accident. RSTART > 1 is
    # therefore tested first, and the empty string it falls back to matches
    # nothing in the class, so an ID at position 1 is accepted deliberately.
    #
    # A rejected match is walked past rather than abandoning the cell, so a cell
    # reading XACME-0001 ACME-0002 still yields ACME-0002.
    #
    # This is cell_id from roadmap-append.sh in sift-prime, restated by the same
    # recorded decision as the pattern above: AGENTS.md under "Duplication
    # between skills" (SFT-0038) keeps one copy of the rule per skill and pays for
    # it with the agreement test, "the reader and the writer classify every cell
    # of one table alike" in tests/scripts/prime-backlog.test.sh, which drives one
    # fixture table through both skills. Change this copy and the sift-prime one in
    # the same commit, and run that test to prove they still agree. Only the
    # parameter is renamed here, so it does not shadow the struck-flag array s
    # below.
    function cell_id(cs,   id, before) {
      while (match(cs, pat)) {
        id = substr(cs, RSTART, RLENGTH)
        before = (RSTART > 1) ? substr(cs, RSTART - 1, 1) : ""
        if (before !~ /[[:alnum:]]/) return id
        cs = substr(cs, RSTART + RLENGTH)
      }
      return ""
    }
    /^##[[:space:]]*[Ww]ave[[:space:]]/ {
      seen_wave = 1
      h = $0
      sub(/^##[[:space:]]*[Ww]ave[[:space:]]+/, "", h)
      sub(/[^0-9].*$/, "", h)
      wave = h + 0
      next
    }
    /^##[[:space:]]/ { wave = 0; next }         # any other heading closes the wave
    !/^[[:space:]]*\|/ { next }                 # table rows only
    NF < 3 { next }
    {
      # The ticket cell is the first cell that HOLDS an ID, not the first cell
      # the pattern matches somewhere inside. Selecting on the bare pattern lets
      # a mistyped XACME-0001 in column 2 shadow the real ticket cell to its
      # right, and reports a row for a cell that holds no ID at all.
      cell = 0
      rid = ""
      for (i = 1; i <= NF; i++) { rid = cell_id($i); if (rid != "") { cell = i; break } }
      if (!cell) next
      n++
      w[n] = wave
      d[n] = rid
      o[n] = (cell > 2) ? trim($2) : n
      t[n] = trim($(cell + 1)); gsub(/~~/, "", t[n])
      s[n] = ($cell ~ /~~/ || $(cell + 1) ~ /~~/) ? 1 : 0
    }
    END {
      for (i = 1; i <= n; i++) {
        wv = seen_wave ? w[i] : 1
        if (wv == 0) continue                   # row outside every wave section
        printf "%d\t%s\t%s\t%d\t%s\n", wv, o[i], d[i], s[i], t[i]
      }
    }
  ' "$ROADMAP"
}

# --- Ticket files -----------------------------------------------------------
# Absolute path of the ticket file for an ID (open/ first, then archive/).
ticket_file() {
  find "$SIFT/open" "$SIFT/archive" -name "$1--*.md" 2>/dev/null | sort | head -n 1
}

# One front-matter value, unquoted, or empty when the key is absent.
fm_value() {
  awk -v key="$2" '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && $0 ~ "^" key ":" {
      sub("^" key ":[[:space:]]*", "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$1"
}

# One label per line from a ticket's `labels: [a, b]` front-matter (flow list only).
fm_labels() {
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, "")
      sub(/^\[/, "")
      sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, parts, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
        if (parts[i] != "") print parts[i]
      }
      exit
    }
  ' "$1"
}

# --- Labels -----------------------------------------------------------------
# One definition of a well-formed label, read by both halves of the label index.
# README.md specifies `labels:` as free-form kebab-case, so this is a convention
# rule and not a per-script preference — and a second copy of it is exactly how
# list-labels.sh comes to advertise a label tickets-by-label.sh then refuses.
#
# An extended regex, handed to `grep -E` below and to awk in list-labels.sh,
# never to a shell glob. The character sets are written out rather than as
# collated ranges: a bracket range is locale-dependent, so under a UTF-8 locale
# it can accept characters the set never named, and this pattern is what decides
# whether a value is accepted. static/portability.test.sh bans the short form in
# a shell pattern for that reason, and the reason carries to a regex that judges
# a value. It reaches awk through the environment rather than -v, which re-scans
# its argument for ANSI escapes: no backslash appears below today, and a future
# one must not be silently rewritten on the way in.
SIFT_LABEL_RE='^[abcdefghijklmnopqrstuvwxyz0123456789]+(-[abcdefghijklmnopqrstuvwxyz0123456789]+)*$'

# True when one label is well-formed. tickets-by-label.sh tests a single
# argument and fits this; list-labels.sh sweeps every label of every ticket and
# reads SIFT_LABEL_RE inside its awk pass instead, so no process is spent per
# label.
label_is_kebab() {
  printf '%s\n' "$1" | grep -qE "$SIFT_LABEL_RE"
}

# --- Clusters ---------------------------------------------------------------
# A ticket's optional `cluster` front-matter value: the advisory name of a root
# cause several tickets share, which next-ticket.sh --group batches into a
# single dispatch. Empty when the key is absent, and empty when the value is
# not a well-formed kebab label — `cluster` widens a dispatch and never
# authorises one, so a malformed value degrades to a group of one rather than
# stopping a run over a field nothing else in the convention requires.
#
# It is one namespace with `labels:`, so it is judged by SIFT_LABEL_RE through
# label_is_kebab rather than by a second pattern: a value list-labels.sh would
# warn about must not be a value the drain silently batches on.
#
# The read goes through fm_value's fence walk and never through a `^cluster:`
# grep, because a body line reading "cluster: caching" matches that anchor
# exactly as a front-matter line does — the defect SFT-0016 and SFT-0020 fixed
# elsewhere on this skill.
ticket_cluster() {
  local value
  value="$(fm_value "$1" cluster)"
  [ -n "$value" ] || return 0
  label_is_kebab "$value" || return 0
  printf '%s\n' "$value"
}

# --- Effort -----------------------------------------------------------------
# The dispatch weight of one `effort` value — the unit next-ticket.sh --group
# sizes a batch in, so that four extra-large tickets can never ride out on one
# dispatch just because four is the count bound.
#
# README.md fixes the closed set xs|s|m|l|xl. Anything else — an absent key, a
# typo, a value from a spec newer than this script — weighs what `m` weighs,
# because refusing to size an unrecognised effort would stop a drain over a
# front-matter value the selection path otherwise only echoes. A case statement
# rather than an associative array: this file is sourced by whatever bash the
# machine has, and nothing else in it needs bash 4.
effort_weight() {
  case "${1:-}" in
    xs) echo 1 ;;
    s)  echo 2 ;;
    m)  echo 3 ;;
    l)  echo 5 ;;
    xl) echo 8 ;;
    *)  echo 3 ;;
  esac
}

# Print absolute directories to search. Pass --open to skip archive/.
ticket_search_dirs() {
  if [ "${1:-}" = "--open" ]; then
    printf '%s\n' "$SIFT/open"
  else
    printf '%s\n' "$SIFT/open" "$SIFT/archive"
  fi
}
