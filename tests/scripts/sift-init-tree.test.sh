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

# --- A fresh tree ------------------------------------------------------------

test_case "a fresh init materialises everything the gate requires"
root="$(newdir)"
init "$root" --milestone v1-2
assert_eq 0 "$R_STATUS" "exits 0"
for entry in README.md MILESTONES.md ROADMAP.md config/config.yaml schemas open archive open/v1-2; do
  if [ -e "$root/.ai/sift/$entry" ]; then t_ok "$entry exists"
  else t_fail "$entry exists" "tree: $(find "$root/.ai" | head -n 20)"; fi
done

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
