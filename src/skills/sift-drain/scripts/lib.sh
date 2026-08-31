#!/usr/bin/env bash
# Shared helpers for the sift-drain scripts. Sourced, never executed directly.
#
# Provides:
#   ROOT / SIFT / ROADMAP / PREFIX  — resolved absolute paths and the ticket prefix
#   roadmap_rows                    — TSV of every roadmap ticket row
#   ticket_rows                     — TSV of every ticket file, in dispatch order
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
#   SIFT_ROOT    project root (default: nearest ancestor of $PWD with .ai/sift/)
#   SIFT_PREFIX  ticket prefix (default: .ai/sift/config/config.yaml, then inferred)

# --- Project root -----------------------------------------------------------
# Walk upward for the nearest `.ai/sift/` directory. ROADMAP.md is validated
# separately so an incomplete tree reports its actual missing file.
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
  # Infer from the most common existing ticket prefix.
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
# Only markdown table rows count. The first cell holding a whole-token ID owns
# the row; Title/Needs mentions and IDs glued to longer words do not.
# Rows under "## Wave <n>" headings are grouped by wave; a roadmap with no wave
# headings is reported as a single wave 1.
roadmap_rows() {
  awk -F'|' -v prefix="$PREFIX" '
    # This is a single-quoted shell string; keep awk comments free of apostrophes.
    # POSIX [[:space:]] avoids undefined backslashes in bracket expressions.
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    # Greedy digits preserve IDs wider than %04d and provide the right whole-token
    # boundary. Keep this rule in sync with sift-prime roadmap-append.sh and run
    # the cross-skill roadmap-row agreement test.
    BEGIN { pat = prefix "-[0-9][0-9][0-9][0-9][0-9]*" }
    # Return the first whole-token ID in a cell. Walk past a left-glued match so a
    # later valid ID remains visible. Keep this cell_id in sync with sift-prime
    # roadmap-append.sh and run the same cross-skill agreement test.
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
      # Select on validated cell_id, not a bare substring match.
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
# Shared kebab-label regex for grep and awk consumers. Spell out character sets
# to avoid locale-collated ranges; pass to awk through ENVIRON, not escape-reading -v.
SIFT_LABEL_RE='^[abcdefghijklmnopqrstuvwxyz0123456789]+(-[abcdefghijklmnopqrstuvwxyz0123456789]+)*$'

# True when one label is well formed.
label_is_kebab() {
  printf '%s\n' "$1" | grep -qE "$SIFT_LABEL_RE"
}

# --- Clusters ---------------------------------------------------------------
# Return a valid optional cluster or empty. Malformed advisory values degrade to
# a group of one. Reuse the label regex and the front-matter fence walker.
ticket_cluster() {
  local value
  value="$(fm_value "$1" cluster)"
  [ -n "$value" ] || return 0
  label_is_kebab "$value" || return 0
  printf '%s\n' "$value"
}

# --- Effort -----------------------------------------------------------------
# Dispatch weight for xs|s|m|l|xl. Unknown values degrade to m instead of
# blocking selection; use a case statement for pre-bash-4 compatibility.
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

# --- Ticket front matter ----------------------------------------------------
# Print one TSV line per ticket file, open/ and archive/ alike:
#   wave <TAB> priority <TAB> ID <TAB> done(0|1) <TAB> status <TAB> effort
#     <TAB> depends_on <TAB> title <TAB> file
#
# The wave is the ticket's own `wave:` key; a ticket carrying none is reported
# as wave 0, never assigned to a guessed one. `done` is the bucket, which is the
# only place resolution is recorded once a ticket is archived.
#
# Rows come out in dispatch order: wave ascending with the unkeyed ones last,
# then `priority` — the intra-wave order — then ID. The sort key is built as a
# leading field and cut back off, so a missing priority sorts behind p0..p9
# instead of in front of it.
#
# An absent optional value is written as a single hyphen, never as an empty
# field. A tab is IFS whitespace, so bash collapses a run of them: a row holding
# one empty field would hand every field behind it to the wrong variable, and
# `read` would report a title as a dependency rather than failing.
ticket_rows() {
  local files=() f
  while IFS= read -r f; do
    [ -n "$f" ] && files+=("$f")
  done < <(find "$SIFT/open" "$SIFT/archive" -name "$PREFIX-*.md" 2>/dev/null)
  [ "${#files[@]}" -gt 0 ] || return 0
  awk '
    # This is a single-quoted shell string; keep awk comments free of apostrophes.
    # POSIX classes avoid both undefined backslashes and collated ranges.
    # A quoted scalar is unwrapped by comparing the two ends, so the quote
    # characters never have to appear inside a regex literal here.
    function dequote(s,   q, first, last) {
      q = sprintf("%c", 39)
      if (length(s) < 2) return s
      first = substr(s, 1, 1)
      last = substr(s, length(s), 1)
      if (first == last && (first == "\"" || first == q))
        return substr(s, 2, length(s) - 2)
      return s
    }
    # The ID falls back to the filename so a ticket whose front matter is being
    # repaired is still reported rather than silently dropped.
    function basename(p,   n, parts) {
      n = split(p, parts, "/")
      return parts[n]
    }
    function given(s) { return (s == "") ? "-" : s }
    function flush(   w, key) {
      if (path == "") return
      if (id == "") { id = basename(path); sub(/--.*$/, "", id) }
      w = (wave ~ /^[0-9][0-9]*$/) ? wave + 0 : 0
      key = sprintf("%06d\t%s\t%s", (w > 0) ? w : 999999, (pri == "") ? "zzz" : pri, id)
      printf "%s\t%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n",
        key, w, given(pri), id, done, given(status), given(effort),
        given(deps), given(title), path
      path = ""
    }
    FNR == 1 {
      flush()
      path = FILENAME
      id = ""; title = ""; status = ""; pri = ""; effort = ""; wave = ""; deps = ""
      done = (index(FILENAME, "/archive/") > 0) ? 1 : 0
      infm = ($0 ~ /^---[[:space:]]*$/) ? 1 : 0
      next
    }
    infm && /^---[[:space:]]*$/ { infm = 0; next }
    infm {
      if ($0 !~ /^[[:alpha:]_][[:alnum:]_]*:/) next
      k = $0; sub(/:.*$/, "", k)
      v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
      v = dequote(v)
      if (k == "id") id = v
      else if (k == "title") title = v
      else if (k == "status") status = v
      else if (k == "priority") pri = v
      else if (k == "effort") effort = v
      else if (k == "wave") wave = v
      else if (k == "depends_on") deps = v
    }
    END { flush() }
  ' "${files[@]}" | LC_ALL=C sort | cut -f4-
}
