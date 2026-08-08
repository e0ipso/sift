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
assert_no_dir "$root/.ai" "asking for help materialises nothing"

summary
