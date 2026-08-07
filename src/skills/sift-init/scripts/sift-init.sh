#!/usr/bin/env bash
# sift-init: materialise a sift tree at an already-resolved root. Idempotent.
#
# This script does NOT decide where the root is — sift-gate.sh does, and its answer is
# passed in with --root. Separating them keeps the only write in the system downstream
# of a single deterministic resolution.
#
# Usage:
#   sift-init.sh --root PATH --prefix ABCD [--milestone NAME]
#   sift-init.sh --suggest-prefix --root PATH
#
# --suggest-prefix prints the derived default prefix and exits; it writes nothing.
# Derivation: basename of the root, non-alphanumerics stripped, uppercased, first 4
# characters. Exits 1 with no output when that yields nothing usable — the caller must
# then ask. The prefix is immutable for the life of the repository, so it is confirmed
# with the user before any file is written, never assumed.
#
# Every write is create-if-absent. Re-running on a populated tree repairs what is
# missing and touches nothing else, so an interrupted or partial init is recoverable by
# running it again.
#
# Exit codes: 0 created or repaired, 2 usage/environment error.

set -u

root=''; prefix=''; milestone='backlog'; suggest=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)           root="${2:-}"; shift 2 ;;
    --prefix)         prefix="${2:-}"; shift 2 ;;
    --milestone)      milestone="${2:-}"; shift 2 ;;
    --suggest-prefix) suggest=1; shift ;;
    -h|--help)        sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$root" ] || { echo "error: --root is required" >&2; exit 2; }
root=$(cd "$root" 2>/dev/null && pwd -P) || {
  echo "error: --root is not a readable directory" >&2; exit 2; }

# --- Prefix derivation ------------------------------------------------------

derive_prefix() {
  basename "$1" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]' | cut -c1-4
}

# The prefix is baked into every ticket ID, filename and PREFIX-XXXX cross-reference, and
# into the globs and regexes every later recipe builds from it, so the WHOLE value is
# validated — 2 or more characters, the first an uppercase ASCII letter, the rest
# uppercase ASCII letters or digits. Testing only the leading three characters let
# `ABC!;rm` reach config.yaml, where the shell metacharacters became every downstream
# recipe's problem.
#
# The allowed set is spelled out character by character instead of written `[A-Z0-9]`:
# a glob range is collated, and under a UTF-8 locale the order is aAbBcC…zZ, so `[A-Z]`
# also matches `b`..`z` and a lowercase prefix would slip through on exactly the machines
# the range was meant to be portable to. An explicit list collates the same everywhere.
#
# `?*` after the leading letter is what enforces the minimum of two; the maximum is a
# length test, because a glob cannot count. The first branch has already rejected every
# character outside the set, newlines included.
prefix_is_well_formed() {  # prefix_is_well_formed <value>
  case "$1" in
    ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*)  return 1 ;;
    [ABCDEFGHIJKLMNOPQRSTUVWXYZ]?*)                return 0 ;;
    *)                                             return 1 ;;
  esac
}

# Every prefix check runs BEFORE the first mkdir below, so a rejected value never leaves a
# half-built tree behind.
if [ "$suggest" -eq 1 ]; then
  candidate=$(derive_prefix "$root")           # already <= 4 characters, so length is moot
  prefix_is_well_formed "$candidate" || exit 1
  printf '%s\n' "$candidate"; exit 0
fi

[ -n "$prefix" ] || { echo "error: --prefix is required (use --suggest-prefix for a default)" >&2; exit 2; }
prefix_is_well_formed "$prefix" || {
  echo "error: prefix must be 2-8 uppercase alphanumerics starting with a letter: $prefix" >&2; exit 2; }
[ ${#prefix} -le 8 ] || { echo "error: prefix must be at most 8 characters: $prefix" >&2; exit 2; }
# The milestone becomes a path component under .ai/sift/open, so the WHOLE value is
# validated as lowercase kebab-case before any write. Testing only the first character
# let `a/../../../evil` through, and `mkdir -p` then resolved it outside the tree.
#
# The allowed set is spelled out character by character instead of written `[a-z0-9-]`:
# a glob range is collated, and under a UTF-8 locale the order is aAbBcC…zZ, so `[a-z]`
# also matches `B`..`Z` and an uppercase name would slip through. An explicit list
# collates the same everywhere.
case "$milestone" in
  ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
    echo "error: milestone must be lowercase kebab-case: $milestone" >&2; exit 2 ;;
esac

# --- Locate the card's assets ----------------------------------------------

here=$(cd "$(dirname "$0")" && pwd -P)
assets="$here/../assets"
[ -d "$assets" ] || { echo "error: card assets not found at $assets" >&2; exit 2; }
[ -f "$assets/README.md" ] || { echo "error: $assets/README.md is missing" >&2; exit 2; }

sift="$root/.ai/sift"
created=''; kept=''

note_created() { created="${created}  created  ${1}
"; }
note_kept()    { kept="${kept}  kept     ${1}
"; }

# --- Claim the tree ---------------------------------------------------------
# Bare mkdir, never `mkdir -p`: it fails when the directory exists, which makes one
# syscall serve as both the "already there?" test and the lock. Exactly one of N
# concurrent agents wins it and the losers fall through to the repair path — the
# concurrency shape the convention requires.
#
# The lock covers the directory, not each file: a loser racing the winner can write a
# file the winner is also writing. Harmless here because both write identical bytes,
# and the alternative (flock) is Linux-only. No ticket is ever at risk — this script
# only ever creates scaffolding that does not yet exist.

mkdir -p "$root/.ai" || exit 2
if mkdir "$sift" 2>/dev/null; then
  fresh=1
  note_created ".ai/sift/"
else
  fresh=0
  [ -d "$sift" ] || { echo "error: cannot create $sift" >&2; exit 2; }
  note_kept ".ai/sift/ (existing tree — repairing)"
fi

install_file() {  # install_file <source> <relative destination>
  if [ -e "$sift/$2" ]; then note_kept ".ai/sift/$2"; return 0; fi
  mkdir -p "$(dirname "$sift/$2")" || return 2
  cp "$1" "$sift/$2" || return 2
  note_created ".ai/sift/$2"
}

write_file() {   # write_file <relative destination>  (body on stdin)
  if [ -e "$sift/$1" ]; then note_kept ".ai/sift/$1"; cat > /dev/null; return 0; fi
  mkdir -p "$(dirname "$sift/$1")" || return 2
  cat > "$sift/$1" || return 2
  note_created ".ai/sift/$1"
}

# --- The convention itself, copied never generated --------------------------
# README.md and schemas/ are the normative spec. A regenerated paraphrase is spec
# drift, so they ship as card assets and are copied byte for byte.

install_file "$assets/README.md" "README.md" || exit 2
for x in "$assets"/schemas/*.xsd; do
  [ -f "$x" ] || continue
  install_file "$x" "schemas/$(basename "$x")" || exit 2
done

# --- Tracking policy --------------------------------------------------------
# Self-contained: the tree ignores itself rather than the repository's root
# .gitignore reaching down into it, so init never edits a file it does not own.
# Deleting this one file is the whole opt-in to tracking tickets in git, so it is written
# ONLY on a fresh tree. Repairs leave it alone and sift-gate.sh does not list it as a
# required entry — otherwise an absence that means "I chose to track my tickets" would
# read as a defect and be undone on every repair.

if [ "$fresh" -eq 1 ]; then
  write_file ".gitignore" <<'EOF'
*
!.gitignore
EOF
else
  if [ -e "$sift/.gitignore" ]; then
    note_kept ".ai/sift/.gitignore"
  else
    note_kept ".ai/sift/.gitignore (absent — tracking is the user's choice)"
  fi
fi

# --- Per-repository configuration -------------------------------------------

write_file "config/config.yaml" <<EOF
# Sift per-repository configuration.
#
# The prefix is immutable for the life of the repository: it is baked into every
# ticket ID, every filename, and every inline PREFIX-XXXX cross-reference. Changing
# it means renaming every ticket file and rewriting every reference in one change.
prefix: $prefix
EOF

write_file "MILESTONES.md" <<EOF
# Milestones

Milestones in intended order. The set is open: add one here in the same change that
creates the first ticket in it, and create the matching \`open/<milestone>/\` folder.

A milestone name is both a folder name and a front-matter value, so renaming one means
moving files and editing \`milestone:\` in the same change.

## $milestone

Work that has not been assigned to a named milestone yet. Split it into real milestones
as soon as the work has shape — a single catch-all milestone gives \`ROADMAP.md\` nothing
to order.
EOF

write_file "ROADMAP.md" <<'EOF'
# Roadmap

Advisory resolution order. When this file and a ticket's `depends_on` disagree,
`depends_on` wins and this file is the thing that gets corrected.

A `~~struck~~` row is finished. Striking the row and archiving the ticket are ONE
change, in the same commit as the implementation (README.md, rule 9).

## Wave 1

| # | Ticket | Title | Needs |
|---|---|---|---|
EOF

# No .gitkeep: the tree ignores itself, so a placeholder whose only job is to make git
# track an empty directory has no job here.
for d in "open/$milestone" "archive"; do
  if [ -d "$sift/$d" ]; then
    note_kept ".ai/sift/$d/"
  else
    mkdir -p "$sift/$d" || exit 2
    note_created ".ai/sift/$d/"
  fi
done

# --- Report -----------------------------------------------------------------

printf 'sift tree at %s\n\n' "$sift"
printf '%s' "$created"
printf '%s' "$kept"
printf '\nprefix: %s   first milestone: %s\n' "$prefix" "$milestone"

# Verify the tree the gate will actually see, from the root we just wrote to.
if SIFT_ROOT="$root" "$here/sift-gate.sh" > /dev/null 2>&1; then
  printf 'gate: READY\n'
else
  printf 'gate: NOT READY — run %s from inside %s for details\n' "$here/sift-gate.sh" "$root"
  exit 2
fi
