#!/usr/bin/env bash
# sift-init.sh — the tree materializer itself (SFT-0008).
#
# The input validators have their own files (sift-init-prefix, sift-init-milestone)
# and the byte-for-byte asset copy has convention-assets. What is pinned here is
# the write path: what a fresh tree contains, and the repair contract that makes
# an interrupted init recoverable by running it again.
#
# Every write is create-if-absent, which is what lets a second run repair a
# partial tree without clobbering an operator's edits. The one deliberate
# exception is .gitignore: it is written ONLY on a fresh tree, because deleting
# it is the whole opt-in to tracking tickets in git, and a repair that restored
# it would silently undo that choice on every run.
#
# Nothing here ever runs against the real repository: --root always points into
# TMPROOT, and the gate verification init performs at the end is given the same
# sandboxed root.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

CARD="$REPO_ROOT/src/skills/sift-init/scripts"
INIT="$CARD/sift-init.sh"
CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/roadmap-check.sh"

init() {  # init <root> [extra args…]
  local root="$1"; shift
  run_cmd "$root" "$INIT" --root "$root" --prefix ACME "$@"
}

# --- What the layout block draws, against what init writes (SFT-0052) ---------
#
# README.md's directory-layout block is as normative as the cookbook's recipes —
# it is the published shape of the tree — and until SFT-0052 nothing compared it
# against anything. The entry list this file used to iterate was hand-copied and
# shorter than the block in both directions.
#
# The comparison is deliberately asymmetric, because the block is not only an
# inventory. `<milestone>` is a placeholder the *Configuration* section tells a
# reader to substitute, so it is substituted here; `<category>` and
# `<PREFIX>-0001--short-slug.md` are shape rather than a path any initialised
# tree carries. So the strong direction is materialised ⊆ documented, and the
# reverse is asserted against an explicit excused list rather than dropped — a
# one-way comparison never sees a withdrawal.
MS=v1-2

# <documented entry>|<why a freshly initialised tree does not carry it>
LAYOUT_EXCUSED="RUNLOG.md|the spec says so itself: the first dispatch of a drain creates it, so a freshly initialized tree has none
open/$MS/<category>/|shape, not a path: <category> is the closed type set, and a category folder appears with the first ticket filed under it
open/$MS/<category>/<PREFIX>-0001--short-slug.md|shape, not a path: an initialised tree holds no tickets
archive/$MS/<category>/<PREFIX>-0001--short-slug.md|shape, not a path: the archive mirrors open/ and starts empty"

# <materialised entry>|<why the layout block does not draw it>
LAYOUT_UNDOCUMENTED='config/|the prefix file is documented under *Configuration* and required by sift-gate.sh, but the tree diagram omits it entirely (SFT-0061)
config/config.yaml|the same omission: "The prefix lives in `.ai/sift/config/config.yaml`" is prose the diagram never draws'

# The entry column of one of the two lists above.
excused_entries() { printf '%s\n' "$1" | sed 's/|.*//'; }

# documented — the layout block's entries with `<milestone>` resolved the way the
# spec instructs a reader to resolve it.
documented_entries() { layout_entries | sed "s|<milestone>|$MS|"; }

# materialised <root> — every path a tree really carries, relative to .ai/sift
# and with a trailing `/` on each directory, so the two sets are spelled alike.
materialised() {
  find "$1/.ai/sift" -mindepth 1 | LC_ALL=C sort | while read -r p; do
    rel="${p#"$1/.ai/sift/"}"
    if [ -d "$p" ]; then printf '%s/\n' "$rel"; else printf '%s\n' "$rel"; fi
  done
}

# --- A fresh tree ------------------------------------------------------------

test_case "a fresh init materialises every entry the layout block draws"
root="$(newdir)"
init "$root" --milestone "$MS"
assert_eq 0 "$R_STATUS" "exits 0"
DOCUMENTED="$(documented_entries)"
assert_ne "" "$DOCUMENTED" "the directory-layout block extracts from README.md"
for entry in $(set_diff "$DOCUMENTED" "$(excused_entries "$LAYOUT_EXCUSED")"); do
  case "$entry" in
    */) if [ -d "$root/.ai/sift/${entry%/}" ]; then t_ok "$entry is a directory"
        else t_fail "$entry is a directory" "tree: $(materialised "$root")"; fi ;;
    *)  if [ -f "$root/.ai/sift/$entry" ]; then t_ok "$entry is a file"
        else t_fail "$entry is a file" "tree: $(materialised "$root")"; fi ;;
  esac
done

test_case "and materialises nothing the layout block does not draw"
# The direction the old hand-copied list could not have: a file init writes that
# the published shape never mentions is invisible to a subset check. Exactly one
# such entry exists today and it is a README omission, not an init bug, so it is
# carried by name with its reason rather than silently tolerated.
assert_eq "$(excused_entries "$LAYOUT_UNDOCUMENTED")" \
  "$(set_diff "$(materialised "$root")" "$DOCUMENTED")" \
  "every extra path is one the undocumented list names, and every named one is still there"

test_case "every excused entry is still an entry the layout block draws"
# Without this the excused list is a place for a withdrawn path to hide: an entry
# deleted from README would leave the subset check green and the excuse standing.
assert_eq "" "$(set_diff "$(excused_entries "$LAYOUT_EXCUSED")" "$DOCUMENTED")" \
  "nothing is excused that the spec no longer documents"

test_case "the fresh tree is reported as created, and verified by the gate"
assert_contains "$R_OUT" "sift tree at $root/.ai/sift" "the report names the absolute location"
assert_contains "$R_OUT" '  created  .ai/sift/' "created entries are listed"
assert_not_contains "$R_OUT" '  kept     .ai/sift/README.md' "nothing was kept on a fresh tree"
assert_not_contains "$R_OUT" '  stale ' \
  "and nothing is stale — the spec was copied from the asset it is compared against"
assert_contains "$R_OUT" 'prefix: ACME   first milestone: v1-2' "the two immutable choices are echoed"
assert_contains "$R_OUT" 'gate: READY' "init verifies its own work before claiming success"

test_case "the fresh tree ignores itself"
# Self-contained tracking policy: the tree ignores itself rather than the
# repository's root .gitignore reaching down into it, so init never edits a file
# it does not own.
assert_eq '*
!.gitignore' "$(cat "$root/.ai/sift/.gitignore")" "the tree's own .gitignore opts it out of git"

test_case "the scaffolding files carry the shapes the recipes parse"
assert_contains "$(cat "$root/.ai/sift/ROADMAP.md")" '## Wave 1' "ROADMAP.md opens a first wave"
assert_contains "$(cat "$root/.ai/sift/ROADMAP.md")" '| # | Ticket | Title | Needs |' \
  "with the table header roadmap_rows reads"
assert_contains "$(cat "$root/.ai/sift/MILESTONES.md")" '## v1-2' \
  "MILESTONES.md documents the milestone in the same change that creates its folder"
assert_contains "$(cat "$root/.ai/sift/config/config.yaml")" 'prefix: ACME' "the prefix is configured"

test_case "a fresh tree is already rule-9 consistent"
# An initialised tree has no tickets and no roadmap rows, which is the empty
# case every consistency check has to survive rather than divide by.
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 0 "$R_STATUS" "roadmap-check.sh exits 0 on a freshly initialised tree"
assert_contains "$R_OUT" 'OK: 0 roadmap rows / 0 ticket files' "counting nothing, both ways"

test_case "--root, not \$PWD, decides where the tree lands"
elsewhere="$(newdir)"
target="$(newdir)"
run_cmd "$elsewhere" "$INIT" --root "$target" --prefix ACME
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$target/.ai/sift/config/config.yaml" "the tree is at --root"
assert_no_dir "$elsewhere/.ai" "and nothing was written at \$PWD"

# --- Idempotence and repair --------------------------------------------------

test_case "re-running on a complete tree changes nothing"
root="$(newdir)"
init "$root"
before="$(tree_digest "$root")"
init "$root"
assert_eq 0 "$R_STATUS" "the second run exits 0"
assert_eq "$before" "$(tree_digest "$root")" "not one byte of the tree changed"
assert_contains "$R_OUT" 'kept     .ai/sift/ (existing tree — repairing)' \
  "and it says it found an existing tree"
assert_not_contains "$R_OUT" '  created  ' "nothing was created"
assert_not_contains "$R_OUT" '  stale ' \
  "and no spec drift is reported against the copy this run just checked"

test_case "a repair recreates only what is missing"
rm "$root/.ai/sift/ROADMAP.md"
rm -rf "$root/.ai/sift/config"
marker='# operator note'
printf '%s\n' "$marker" >> "$root/.ai/sift/MILESTONES.md"
init "$root"
assert_eq 0 "$R_STATUS" "the repair run exits 0"
assert_contains "$R_OUT" '  created  .ai/sift/ROADMAP.md' "the deleted roadmap is created"
assert_contains "$R_OUT" '  created  .ai/sift/config/config.yaml' "so is the deleted config"
assert_contains "$R_OUT" '  kept     .ai/sift/MILESTONES.md' "the edited file is kept"
assert_contains "$(cat "$root/.ai/sift/MILESTONES.md")" "$marker" "with the operator's edit intact"
assert_contains "$R_OUT" 'gate: READY' "and the repaired tree passes the gate"

test_case "a repair never restores a deleted .gitignore"
# Its absence means "I chose to track my tickets in git". Restoring it would
# undo that decision on every subsequent init.
rm "$root/.ai/sift/.gitignore"
init "$root"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$root/.ai/sift/.gitignore" "the file stays deleted"
assert_contains "$R_OUT" "kept     .ai/sift/.gitignore (absent — tracking is the user's choice)" \
  "and the report explains why it did not come back"

test_case "a repair with a different milestone adds it without moving the first"
root="$(newdir)"
init "$root" --milestone v1-2
init "$root" --milestone v1-3
assert_eq 0 "$R_STATUS" "exits 0"
if [ -d "$root/.ai/sift/open/v1-2" ] && [ -d "$root/.ai/sift/open/v1-3" ]
then t_ok "both milestone folders exist"
else t_fail "both milestone folders exist" "$(find "$root/.ai/sift/open" | head)"; fi
assert_contains "$(cat "$root/.ai/sift/MILESTONES.md")" '## v1-2' \
  "MILESTONES.md keeps the first milestone — create-if-absent does not rewrite it"
assert_not_contains "$(cat "$root/.ai/sift/MILESTONES.md")" '## v1-3' \
  "so the second milestone is the operator's to document, as rule 9 requires"

test_case "a repair keeps the original prefix"
# The prefix is immutable for the life of the repository: config.yaml already
# exists, so create-if-absent must ignore the new value rather than rewrite it.
root="$(newdir)"
init "$root"
run_cmd "$root" "$INIT" --root "$root" --prefix ZZZZ
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$(cat "$root/.ai/sift/config/config.yaml")" 'prefix: ACME' \
  "config.yaml still carries the prefix the repository was created with"
assert_not_contains "$(cat "$root/.ai/sift/config/config.yaml")" 'prefix: ZZZZ' \
  "the second run's value did not overwrite it"

# --- Argument handling -------------------------------------------------------

test_case "argument errors exit 2 before any mkdir"
root="$(newdir)"
run_cmd "$root" "$INIT" --root "$root" --prefix ACME --bogus
assert_eq 2 "$R_STATUS" "an unknown argument exits 2"
assert_contains "$R_ERR" 'unknown argument: --bogus' "naming it"
assert_no_dir "$root/.ai" "and writing nothing"

run_cmd "$root" "$INIT" --prefix ACME
assert_eq 2 "$R_STATUS" "a missing --root exits 2"
assert_contains "$R_ERR" '--root is required' "saying which argument"

run_cmd "$root" "$INIT" --root "$root/nowhere" --prefix ACME
assert_eq 2 "$R_STATUS" "an unreadable --root exits 2"
assert_contains "$R_ERR" '--root is not a readable directory' "rather than creating it"
assert_no_dir "$root/nowhere" "the path is genuinely not created"

test_case "--help prints the usage and writes nothing"
root="$(newdir)"
run_cmd "$root" "$INIT" --help
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'sift-init.sh --root PATH --prefix ABCD' "the usage line is shown"
# --help prints a fixed line range out of the header comment, so a paragraph
# added above the last one silently truncates the usage text unless the range
# moves with it. Anchoring on the final paragraph is what catches that.
assert_contains "$R_OUT" 'must never make on its own.' "through to the end of the header block"
assert_no_dir "$root/.ai" "asking for help materialises nothing"

# --- Rejected arguments arriving at a tree with real work in it (SFT-0008) ---
#
# The cases above run every refusal against an empty root, where "nothing was
# written" costs nothing to be true. The sequence that would actually cost
# something is the same refusal reaching a tree that already holds tickets, a
# roadmap and an operator's edits — a repeat init in a live repository, typed
# with one argument wrong. So this builds that tree for real and diffs it, paths
# and bytes, after each refusal.

# inventory <dir> — every path, directories included: tree_digest reads files
# only, and a stray empty milestone folder is exactly the kind of debris a
# half-applied argument leaves.
inventory() { find "$1" | LC_ALL=C sort; }

test_case "a rejected argument leaves a populated tree untouched"
root="$(newdir)"
init "$root"
mkdir -p "$root/.ai/sift/open/backlog/bug"
printf -- '---\nid: ACME-0001\nstatus: open\n---\n\n# Real work\n' \
  > "$root/.ai/sift/open/backlog/bug/ACME-0001--real.md"
printf '| 1 | ACME-0001 | Real work | - |\n' >> "$root/.ai/sift/ROADMAP.md"
printf '\n## v2\n' >> "$root/.ai/sift/MILESTONES.md"
live_paths="$(inventory "$root")"
live_bytes="$(tree_digest "$root")"

refused() {  # refused <what> <args…>
  local what="$1"; shift
  run_cmd "$root" "$INIT" "$@"
  if [ "$R_STATUS" -eq 2 ] &&
     [ "$live_paths" = "$(inventory "$root")" ] &&
     [ "$live_bytes" = "$(tree_digest "$root")" ]
  then t_ok "$what: exit 2, and the live tree is byte- and path-identical"
  else t_fail "$what: exit 2, and the live tree is byte- and path-identical" \
    "status=$R_STATUS" "stderr=$R_ERR"; fi
}

refused "an unknown argument"    --root "$root" --prefix ACME --bogus
refused "a malformed prefix"     --root "$root" --prefix 'ab!'
refused "an over-long prefix"    --root "$root" --prefix ABCDEFGHI
refused "an empty prefix"        --root "$root" --prefix ''
refused "a traversing milestone" --root "$root" --prefix ACME --milestone '../../../evil'
refused "an uppercase milestone" --root "$root" --prefix ACME --milestone 'V2'

test_case "a repeat init that IS well-formed still changes nothing but says so"
# The control for the six above: the same live tree, the same command line, one
# argument fewer. A refusal that left the tree alone would be worthless if the
# accepted spelling did too little or too much.
run_cmd "$root" "$INIT" --root "$root" --prefix ACME
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$live_bytes" "$(tree_digest "$root")" "the operator's tickets and edits are intact"
assert_contains "$R_OUT" 'gate: READY' "and the tree it declined to rewrite still passes the gate"

# --- Concurrency: the mkdir lock, raced (SFT-0008) ---------------------------
#
# `mkdir "$sift"` is both the "is it already there?" test and the lock: it fails
# when the directory exists, so one of N concurrent initializers claims a fresh
# tree and the rest fall through to repair. Until now that was asserted only by
# running the script twice in sequence, which produces the lock's OUTCOME without
# ever exercising the lock.
#
# The writers below are launched together and reaped with `wait`. That makes the
# overlap real but not forced: nothing guarantees writer 8 reaches its mkdir
# before writer 1 is finished. Forcing it would need a start barrier, and the
# only two ways to build one here are a FIFO — a tool the suite's dependency
# contract in static/suite-contract.test.sh does not list — or a sleep-based
# spin, which this repo forbids outright. So the assertions are written to hold
# under EVERY interleaving instead, from full overlap to complete serialisation.
# A test that is only sometimes right is worse than one that is narrower.

RACERS=8

# race <root> <outdir> — N initializers against one root, all at once.
race() {
  local root="$1" out="$2" i=1
  while [ "$i" -le "$RACERS" ]; do
    ( "$INIT" --root "$root" --prefix ACME > "$out/w$i.log" 2>&1
      echo $? > "$out/w$i.rc" ) &
    i=$((i + 1))
  done
  wait
}

# claims <outdir> <reported entry> — how many writers said they created it.
claims() { grep -l "^  created  $2\$" "$1"/w*.log 2>/dev/null | wc -l | tr -d ' '; }

test_case "the tree itself is claimed by exactly one racing writer"
# The lock's own guarantee: `mkdir` covers the directory, and the fresh path it
# hands the winner is the one that writes the tracking policy and skips every
# "existing tree" repair. Two writers believing they got a FRESH tree is the
# defect this rules out.
raced="$(newdir)"; out="$(newdir)"
race "$raced" "$out"
n="$(claims "$out" '.ai/sift/')"
if [ "$n" -le 1 ]
then t_ok "no two writers report creating .ai/sift/"
else t_fail "no two writers report creating .ai/sift/" "writers claiming a fresh tree: $n"; fi

test_case "a raced tree survives the race"
# SFT-0030. Every write is staged in a temp file beside its destination and
# published with `ln`, whose EEXIST arbitrates the tie: exactly one writer
# creates a given path and every other one keeps what it found. Both properties
# below hold under every interleaving, from full overlap to complete
# serialisation, which is why they are assertions and no longer skips.
#
# Before the fix, a loser reaching `cp` alongside the winner died with a raw
# `cp: … File exists` and exit 2 — GNU cp opens a destination it believes absent
# with O_EXCL rather than overwriting it — and when the dying writer was the one
# holding the lock it took `.ai/sift/.gitignore` with it permanently, because
# that file is fresh-only by design and no repair ever restores it. Measured at
# 75 non-zero exits and 19 trees with no `.gitignore` in 200 eight-way races.
rcs="$(cat "$out"/w*.rc | LC_ALL=C sort -u | tr '\n' ' ')"
assert_eq "0 " "$rcs" "every writer in a race exits 0"
assert_not_contains "$(cat "$out"/w*.log)" 'cp:' \
  "and none of them printed a raw utility diagnostic"
assert_eq '*
!.gitignore' "$(cat "$raced/.ai/sift/.gitignore" 2>/dev/null)" \
  "a raced tree keeps the .gitignore its winner was writing"

# The atomicity itself, stated as a count: `ln` cannot let two writers create the
# same path, so the file the whole race converges on has exactly one author.
n="$(claims "$out" '.ai/sift/README.md')"
assert_eq 1 "$n" "exactly one writer reports creating README.md"

test_case "one sequential repair puts a raced tree back to a complete one"
# The recovery contract: after the race, a single init fills whatever is missing,
# and the result matches an uncontended tree entry for entry — `.gitignore`
# included, now that winning the race is no longer what decides whether it
# exists.
reference="$(newdir)"
init "$reference"
run_cmd "$raced" "$INIT" --root "$raced" --prefix ACME
assert_eq 0 "$R_STATUS" "the repair run exits 0"
assert_contains "$R_OUT" 'gate: READY' "and the repaired tree passes the gate"

rel_digest() {  # rel_digest <root> — tree_digest, root-relative
  ( cd "$1" && tree_digest . )
}
assert_eq "$(rel_digest "$reference")" "$(rel_digest "$raced")" \
  "every file an uncontended init writes is present, and byte-identical"

summary
