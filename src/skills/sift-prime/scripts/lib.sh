#!/usr/bin/env bash
# Shared helpers for the sift-prime scripts. Sourced, never executed directly.
#
# Provides ROOT, SIFT, PREFIX and fm_value. Drain owns ticket rows and label lookup.
# SIFT_ROOT overrides the nearest ancestor holding .ai/sift/.
# SIFT_PREFIX overrides configuration or filename-based inference.
# Walk from $PWD using only the .ai/sift directory marker. Ignore nested .git
# directories, so a monorepo subproject still resolves to its parent tracker.
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
    echo "hint: run sift-init before priming, or point SIFT_ROOT at an initialized tree" >&2
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

# --- Front-matter -----------------------------------------------------------
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
