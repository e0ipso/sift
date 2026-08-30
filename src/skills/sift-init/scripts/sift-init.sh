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
# the one this skill carries, each differing file is listed as `stale` and the `cp` that
# refreshes it is printed. Nothing is rewritten: taking the new copy is the operator's
# explicit act, because these files are also the only place they can annotate the
# convention for their repository.
#
# The report reads the comparison in the other direction too: an installed schema this
# skill no longer ships is listed as `orphan` — not `stale`, because there is no shipped
# copy for its bytes to differ from. That one is not even offered as a `cp`, since the
# refresh copies and cannot remove. The printed remedy is an `rm` for the operator to
# run by hand, because the file may equally be a schema the repository added for itself
# and deleting it is the one repair an initializer must never make on its own.
#
# Exit codes: 0 created or repaired, 2 usage/environment error.

set -u

root=''; prefix=''; milestone='backlog'; suggest=0

# A valued option consumes the word after it, so that word has to exist before the
# `shift 2` that eats it. Against a one-element "$@" the shift fails, and with
# `set -e` deliberately off the failure is discarded — `$1` is then still the same
# option on the next pass and the loop spins on it forever, printing nothing
# (SFT-0044). So the arity is checked per option, ahead of the consumption.
#
# Per option and NOT a parity test on `$#`: this script mixes valued options with
# valueless ones (`--suggest-prefix`, `-h`/`--help`), so the parity of the argument
# count says nothing about whether any single option received its own value. And not
# `set -e` either — that would change the failure mode of every other command in the
# file to fix one loop.
#
# The `"${2:-}"` defaults below stay regardless: they are what keeps the expansion
# legal under `set -u`, and they are evaluated on the branch that has just been
# proved to have a second word only because this guard exits first when it has not.
#
# A missing word is not an empty one. `--root ''` passes here and is refused further
# down by `[ -n "$root" ]`, which is the right diagnostic for it; the two conditions
# are kept apart on purpose.
need_value() {  # need_value <option> <remaining argument count, option included>
  [ "$2" -ge 2 ] || { echo "error: $1 requires a value" >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root)           need_value --root "$#";      root="${2:-}"; shift 2 ;;
    --prefix)         need_value --prefix "$#";    prefix="${2:-}"; shift 2 ;;
    --milestone)      need_value --milestone "$#"; milestone="${2:-}"; shift 2 ;;
    --suggest-prefix) suggest=1; shift ;;
    -h|--help)        sed -n '2,34p' "$0"; exit 0 ;;
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

# --- Locate the skill's assets ----------------------------------------------

here=$(cd "$(dirname "$0")" && pwd -P)
assets="$here/../assets"
[ -d "$assets" ] || { echo "error: skill assets not found at $assets" >&2; exit 2; }
# Canonicalized once the directory is known to exist, so the refresh command the
# drift report prints below is a path an operator can paste, not one with `/..`
# folded through the middle of it.
assets=$(cd "$assets" && pwd -P)
[ -f "$assets/README.md" ] || { echo "error: $assets/README.md is missing" >&2; exit 2; }

sift="$root/.ai/sift"
created=''; kept=''; stale=''; orphan=''; orphan_rm=''

note_created() { created="${created}  created  ${1}
"; }
note_kept()    { kept="${kept}  kept     ${1}
"; }
note_stale()   { stale="${stale}  stale    ${1} (differs from the shipped convention)
"; }
# Takes the path RELATIVE to the tree, not the display string the three above
# take: the finding and the `rm` that answers it must name the same file, and
# deriving both from one argument is what keeps them from drifting apart.
note_orphan()  { orphan="${orphan}  orphan   .ai/sift/${1} (installed, but the shipped convention no longer defines it)
"
                 orphan_rm="${orphan_rm}  rm ${sift}/${1}
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
# drift, so they ship as skill assets and are copied byte for byte.

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
# did not ask to see. The same comparison `sync-assets.sh` makes on the skill's
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

# --- And an installed schema the skill no longer ships? ----------------------
# The loop above walks the SHIPPED set, so its domain is what this skill carries:
# it sees a file whose bytes changed and a file that went missing, but never an
# extra one. A schema sitting in the tree that the convention has since withdrawn
# is invisible to it, and the documented refresh is blind the same way — `cp`
# overwrites what still ships and steps straight over the rest, so the withdrawn
# file survives every refresh an operator runs. A drafter that finds it drafts
# against a shape the convention stopped defining (SFT-0035). Removing a schema
# is a breaking API change, which is exactly the moment an already-initialized
# tree needs telling.
#
# `orphan` and not `stale`: `stale` means the bytes differ from the shipped copy,
# and a file with no shipped copy at all is a different condition with a
# different remedy. Conflating them would print a `cp` that cannot fix it.
#
# Reported, never deleted — the same rule the drift check obeys, for a stronger
# reason. Nothing on disk distinguishes a schema the convention withdrew from one
# this repository wrote for itself, and deleting a file it did not create is the
# one repair an initializer must not make on its own. So this loop only reads:
# the `rm` is printed, and the operator runs it.
#
# The unmatched glob stays literal, so the `[ -f ]` guard is what keeps a tree
# with no schemas at all from being reported as owning one named `*.xsd`. Not
# `nullglob`: this script runs under whatever `sh`-alike bash provides, and the
# guard is the portable spelling the rest of the file already uses.
for x in "$sift"/schemas/*.xsd; do
  [ -f "$x" ] || continue
  base=$(basename "$x")
  [ -f "$assets/schemas/$base" ] || note_orphan "schemas/$base"
done

# --- Per-repository configuration -------------------------------------------

write_file "config/config.yaml" <<EOF
# Sift per-repository configuration.
#
# The prefix is immutable. Changing it requires renaming every ticket file and
# rewriting every reference in the same change.
prefix: $prefix
EOF

write_file "MILESTONES.md" <<EOF
# Milestones

Milestones, in intended order. With a milestone's first ticket, add it here and
create the matching \`open/<milestone>/\` folder.

Rename a milestone by moving every ticket file and updating its \`milestone:\` in
the same change.

## $milestone

Initial backlog for work not assigned to a named milestone.
EOF

write_file "ROADMAP.md" <<'EOF'
# Roadmap

Advisory order; a ticket's `depends_on` takes precedence.

Strike a finished row and archive its ticket in the same change.

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
# does not contain. So the two commands are printed here, from the skill, where
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

# The `cp` above cannot answer this one: it copies, so it overwrites what still
# ships and leaves a withdrawn schema exactly where it is. The remedy is a
# deletion, and a deletion is the one thing this script will not do for you —
# hence a command to run rather than an action taken.
if [ -n "$orphan" ]; then
  printf '%s' "$orphan"
  printf '\nThat file is installed under a name this skill no longer ships. Either the\n'
  printf 'convention withdrew the schema — removing one is a breaking change, which is why\n'
  printf 'you are being told — or your repository added a schema of its own, which is\n'
  printf 'yours to keep. Nothing here can tell those two apart, and deleting a file it did\n'
  printf 'not create is the one repair an initializer must never make on its own, so it is\n'
  printf 'left in place and named. Remove it by hand if the convention dropped it:\n\n'
  printf '%s' "$orphan_rm"
fi

printf '\nprefix: %s   first milestone: %s\n' "$prefix" "$milestone"

# Verify the tree the gate will actually see, from the root we just wrote to.
if SIFT_ROOT="$root" "$here/sift-gate.sh" > /dev/null 2>&1; then
  printf 'gate: READY\n'
else
  printf 'gate: NOT READY — run %s from inside %s for details\n' "$here/sift-gate.sh" "$root"
  exit 2
fi
