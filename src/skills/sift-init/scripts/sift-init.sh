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
# The one thing a re-run adds is a report. README.md and schemas/ are the shipped
# convention rather than repository state, so when an installed copy no longer matches
# the one this card carries, each differing file is listed as `stale` and the `cp` that
# refreshes it is printed. Nothing is rewritten: taking the new copy is the operator's
# explicit act, because these files are also the only place they can annotate the
# convention for their repository.
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
    -h|--help)        sed -n '2,27p' "$0"; exit 0 ;;
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
# Canonicalized once the directory is known to exist, so the refresh command the
# drift report prints below is a path an operator can paste, not one with `/..`
# folded through the middle of it.
assets=$(cd "$assets" && pwd -P)
[ -f "$assets/README.md" ] || { echo "error: $assets/README.md is missing" >&2; exit 2; }

sift="$root/.ai/sift"
created=''; kept=''; stale=''

note_created() { created="${created}  created  ${1}
"; }
note_kept()    { kept="${kept}  kept     ${1}
"; }
note_stale()   { stale="${stale}  stale    ${1} (differs from the shipped convention)
"; }

# --- Atomic create-if-absent ------------------------------------------------
# Every scaffolding write goes through install_file or write_file, and both are
# create-if-absent: that is what lets a second run repair a partial tree without
# clobbering an operator's edits.
#
# `[ -e "$dest" ]` and then `cp` is a check-then-act, and the window between the
# two is wide enough to lose a race in. GNU `cp` opens a destination it believes
# absent with O_EXCL rather than truncating, so of two writers that pass the `-e`
# test together the second does not overwrite — it dies with
# `cp: cannot create regular file '…': File exists` (SFT-0030). The `-e` test
# survives as a fast path, because the common case is a repair that writes
# nothing at all, but it no longer decides anything on its own: the write lands
# in a temporary file BESIDE its destination and is published with `ln`, whose
# EEXIST makes one syscall serve as both the "already there?" test and the
# create — exactly the trick the `mkdir` lock below plays on the directory.
#
# `ln` and not a bare `mv`: `mv` overwrites, and create-if-absent is the whole
# repair contract. Losing the link race is therefore not a failure, it is the
# "kept" branch — some other writer put identical bytes there first.
#
# The temporary file lives in the destination's own directory, never `$TMPDIR`:
# neither a hard link nor an atomic rename can cross a filesystem.
#
# Publishing a fully written file under its final name in one step also closes a
# second window SFT-0030 names: `sift-gate.sh` parses `prefix:` out of
# `config/config.yaml`, and a writer that skipped the file on the `-e` test could
# reach that read while the file existed but was still empty.

# new_temp <directory> — an empty private file beside the destination, with the
# permissions the umask would have given a freshly created file. `mktemp` makes
# it 0600 and neither `cp` onto an existing file nor `> "$tmp"` widens that, so
# without the chmod every shipped file would land 0600. A symbolic mode with no
# "who" is masked by the umask, which is precisely the rule being restored.
new_temp() {
  local tmp
  mkdir -p "$1" || return 2
  tmp=$(mktemp "$1/.sift-init.XXXXXX") || return 2
  chmod +rw "$tmp" || { rm -f "$tmp"; return 2; }
  printf '%s\n' "$tmp"
}

# publish <temp path> <relative destination> — consumes the temp file either way.
publish() {
  if ln "$1" "$sift/$2" 2>/dev/null; then
    rm -f "$1"; note_created ".ai/sift/$2"; return 0
  fi
  if [ -e "$sift/$2" ]; then
    rm -f "$1"; note_kept ".ai/sift/$2"; return 0
  fi
  # No link and no destination: a filesystem with no hard links at all (FAT, a
  # few FUSE mounts). Fall back to the rename the cookbook documents as the
  # portable replacement for `sed -i` — still one step and still atomic, only
  # without EEXIST to arbitrate a tie. Reached solely where `ln` cannot work,
  # so it is never worse than the check-then-act it replaces.
  if mv "$1" "$sift/$2" 2>/dev/null; then note_created ".ai/sift/$2"; return 0; fi
  rm -f "$1"
  echo "error: cannot create $sift/$2" >&2
  return 2
}

install_file() {  # install_file <source> <relative destination>
  local tmp
  if [ -e "$sift/$2" ]; then note_kept ".ai/sift/$2"; return 0; fi
  tmp=$(new_temp "$(dirname "$sift/$2")") || {
    echo "error: cannot stage $sift/$2" >&2; return 2; }
  cp "$1" "$tmp" || { rm -f "$tmp"; echo "error: cannot read $1" >&2; return 2; }
  publish "$tmp" "$2"
}

write_file() {   # write_file <relative destination>  (body on stdin)
  local tmp
  if [ -e "$sift/$1" ]; then note_kept ".ai/sift/$1"; cat > /dev/null; return 0; fi
  tmp=$(new_temp "$(dirname "$sift/$1")") || {
    cat > /dev/null; echo "error: cannot stage $sift/$1" >&2; return 2; }
  cat > "$tmp" || { rm -f "$tmp"; echo "error: cannot write $sift/$1" >&2; return 2; }
  publish "$tmp" "$1"
}

# --- Claim the tree ---------------------------------------------------------
# Bare mkdir, never `mkdir -p`: it fails when the directory exists, which makes one
# syscall serve as both the "already there?" test and the lock. Exactly one of N
# concurrent agents wins it and the losers fall through to the repair path — the
# concurrency shape the convention requires.
#
# The lock covers the directory, not each file, and it does not need to: every
# file below is published atomically, so a loser racing the winner onto the same
# path keeps what it finds instead of failing. No ticket is ever at risk — this
# script only ever creates scaffolding that does not yet exist.

mkdir -p "$root/.ai" || exit 2
if mkdir "$sift" 2>/dev/null; then
  fresh=1
  note_created ".ai/sift/"
else
  fresh=0
  [ -d "$sift" ] || { echo "error: cannot create $sift" >&2; exit 2; }
  note_kept ".ai/sift/ (existing tree — repairing)"
fi

# --- Tracking policy --------------------------------------------------------
# Self-contained: the tree ignores itself rather than the repository's root
# .gitignore reaching down into it, so init never edits a file it does not own.
# Deleting this one file is the whole opt-in to tracking tickets in git, so it is written
# ONLY on a fresh tree. Repairs leave it alone and sift-gate.sh does not list it as a
# required entry — otherwise an absence that means "I chose to track my tickets" would
# read as a defect and be undone on every repair.
#
# It is written HERE, first, immediately after the mkdir that claimed the tree and
# before any other write: the fresh path belongs to the lock's winner alone, so a
# winner that died further down used to take this file with it permanently — every
# later run is a repair, and a repair never restores it (SFT-0030). Nothing between
# the mkdir and this write can fail now, so "fresh tree" and "has a .gitignore" can
# no longer come apart.

if [ "$fresh" -eq 1 ]; then
  write_file ".gitignore" <<'EOF' || exit 2
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

# --- The convention itself, copied never generated --------------------------
# README.md and schemas/ are the normative spec. A regenerated paraphrase is spec
# drift, so they ship as card assets and are copied byte for byte.

install_file "$assets/README.md" "README.md" || exit 2
for x in "$assets"/schemas/*.xsd; do
  [ -f "$x" ] || continue
  install_file "$x" "schemas/$(basename "$x")" || exit 2
done

# --- Is the installed spec still the shipped one? ---------------------------
# `install_file` keeps whatever it finds, which is right for a ROADMAP the
# repository writes to and wrong for these two paths: README.md and schemas/ are
# the only files in the tree that are NOT the repository's to own. They are the
# convention, copied in whole at install time, and nothing ever writes to them
# again — so the copy freezes on the day the tree was created and every cookbook
# fix landed since is invisible to the agents reading it (SFT-0032).
#
# The answer is a report, never a repair. Refreshing implicitly would rewrite a
# file an operator may have annotated, which breaks the same trust `note_kept`
# exists to protect, so `check_drift` only ever reads: no temp file, no publish,
# no branch that writes. Silence when the bytes match, so an up-to-date
# installation — including every fresh one, which was just copied from these
# exact bytes — sees nothing new.
#
# `cmp -s` and not `diff`: a byte verdict is the whole question, it is already in
# the suite's baseline dependency contract, and it prints nothing the operator
# did not ask to see. The same comparison `sync-assets.sh` makes on the card's
# side of the copy, now made on the consuming side too.

check_drift() {  # check_drift <shipped source> <relative destination> — reads only
  [ -f "$sift/$2" ] || return 0
  cmp -s "$1" "$sift/$2" || note_stale ".ai/sift/$2"
}

check_drift "$assets/README.md" "README.md"
for x in "$assets"/schemas/*.xsd; do
  [ -f "$x" ] || continue
  check_drift "$x" "schemas/$(basename "$x")"
done

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

# The report carries the remedy, not just the finding. The refresh is documented
# in the cookbook, but the cookbook lives IN the file that is out of date — an
# operator holding the stale copy would be told to read an instruction their copy
# does not contain. So the two commands are printed here, from the card, where
# they are always as current as the drift check that triggered them.
if [ -n "$stale" ]; then
  printf '%s' "$stale"
  printf '\nThose files are the convention itself, shipped whole — not repository state:\n'
  printf 'no ticket, roadmap, milestone list or config lives in them, so they are the only\n'
  printf 'two paths in the tree that are safe to overwrite. Nothing else here may be.\n'
  printf 'Take the current copy when you are ready (review first if you annotated either):\n\n'
  printf '  cp %s/README.md %s/README.md\n' "$assets" "$sift"
  printf '  cp %s/schemas/*.xsd %s/schemas/\n' "$assets" "$sift"
fi

printf '\nprefix: %s   first milestone: %s\n' "$prefix" "$milestone"

# Verify the tree the gate will actually see, from the root we just wrote to.
if SIFT_ROOT="$root" "$here/sift-gate.sh" > /dev/null 2>&1; then
  printf 'gate: READY\n'
else
  printf 'gate: NOT READY — run %s from inside %s for details\n' "$here/sift-gate.sh" "$root"
  exit 2
fi
