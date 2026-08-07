#!/usr/bin/env bash
# Shared helpers for the sift-drain scripts. Sourced, never executed directly.
#
# Provides:
#   ROOT / SIFT / ROADMAP / PREFIX  — resolved absolute paths and the ticket prefix
#   roadmap_rows                    — TSV of every roadmap ticket row
#   ticket_file <ID>                — absolute path of a ticket file, or empty
#   fm_value <file> <key>           — one front-matter value
#   fm_labels <file>                — one label per line from labels: [...]
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
  echo "hint: rule 9 requires every ticket to have a roadmap row — create it first" >&2
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
# Only markdown table rows count, and only the FIRST cell holding an ID is the
# ticket cell — so ID mentions in a Title or Needs column never register as rows.
# Rows under "## Wave <n>" headings are grouped by wave; a roadmap with no wave
# headings is reported as a single wave 1.
roadmap_rows() {
  awk -F'|' -v prefix="$PREFIX" '
    # [[:space:]], not [ \t]: POSIX leaves a backslash inside a bracket
    # expression undefined, so a strict awk reads [ \t] as {space, \, t} and
    # eats the leading "t" of a title like "tenant caching".
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    BEGIN { pat = prefix "-[0-9][0-9][0-9][0-9]" }
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
      cell = 0
      for (i = 1; i <= NF; i++) if ($i ~ pat) { cell = i; break }
      if (!cell) next
      match($cell, pat)
      n++
      w[n] = wave
      d[n] = substr($cell, RSTART, RLENGTH)
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

# Print absolute directories to search. Pass --open to skip archive/.
ticket_search_dirs() {
  if [ "${1:-}" = "--open" ]; then
    printf '%s\n' "$SIFT/open"
  else
    printf '%s\n' "$SIFT/open" "$SIFT/archive"
  fi
}
