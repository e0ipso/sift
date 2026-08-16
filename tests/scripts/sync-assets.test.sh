#!/usr/bin/env bash
# sync-assets.sh — the one command that keeps the skill's assets current (SFT-0006).
#
# Every case runs against a throwaway copy of the skill layout, never the real
# repository, because the script's whole job is to write.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

REAL_CARD="$REPO_ROOT/src/skills/sift-init"

# A minimal repository with the skill's shape: the script resolves its paths from
# its own location, so the copy must keep src/skills/sift-init/scripts/.
fake_repo() {
  local t skill
  t="$(newdir)"
  skill="$t/src/skills/sift-init"
  mkdir -p "$skill/scripts" "$skill/assets/schemas" "$t/schemas"
  cp "$REAL_CARD/scripts/sync-assets.sh" "$skill/scripts/"
  printf '# normative spec\n' > "$t/README.md"
  printf '<xsd>one</xsd>\n' > "$t/schemas/one.xsd"
  printf '<xsd>two</xsd>\n' > "$t/schemas/two.xsd"
  printf '%s\n' "$t"
}

sync() { run_cmd "$1" "${R_SHELL:-bash}" "$1/src/skills/sift-init/scripts/sync-assets.sh"; }

assets_of() { printf '%s' "$1/src/skills/sift-init/assets"; }

# The same skill, parked where the script's three-levels-up walk lands on a tree
# that is not a sift checkout at all: the relocated skill the root guard exists
# for. Everything the four preconditions ask for is present, so the run reaches
# that guard with nothing above it refusing first.
relocated_repo() {
  local t skill
  t="$(newdir)"
  skill="$t/nested/skills/sift-init"
  mkdir -p "$skill/scripts" "$skill/assets/schemas" "$t/schemas"
  cp "$REAL_CARD/scripts/sync-assets.sh" "$skill/scripts/"
  printf '# some other tree spec\n' > "$t/README.md"
  printf '<xsd>one</xsd>\n' > "$t/schemas/one.xsd"
  printf '%s\n' "$t"
}

relocated_card() { printf '%s' "$1/nested/skills/sift-init"; }

# A PATH prepend whose cp and rm report success without doing anything. It is
# the fault the verification block is written against — an incomplete copy with
# every command reporting success — and it reaches the block without a trick:
# no symlink to a character device, no unwritable directory aborting the run
# under set -e before the block is ever entered.
noop_shim() {  # noop_shim <dir> → the dir, ready to prepend to PATH
  local d="$1" c
  mkdir -p "$d"
  for c in cp rm; do
    printf '#!/bin/sh\nexit 0\n' > "$d/$c"
    chmod +x "$d/$c"
  done
  printf '%s' "$d"
}

# The script's real command line with that shim in front of it. run_cmd passes
# its whole argument list through, so nothing in the harness has to know.
sync_shimmed() {  # sync_shimmed <repo> <shim>
  run_cmd "$1" env PATH="$2:$PATH" bash "$1/src/skills/sift-init/scripts/sync-assets.sh"
}

test_case "the permission helper reports a platform where chmod denies nothing"
# A no-op chmod models uid 0's DAC override without requiring the suite itself
# to run as root.  The probe must report non-zero, restore bytes and mode, and
# leave no probe/backup residue so every caller can turn this result into SKIP.
probe_root="$(newdir)"
mkdir "$probe_root/dir"
printf 'original bytes\n' > "$probe_root/file"
for probe_path in "$probe_root/dir" "$probe_root/file"; do
  probe_mode="$(fixture_mode "$probe_path")"
  probe_bytes=''
  [ -f "$probe_path" ] && probe_bytes="$(cat "$probe_path")"
  (
    chmod() { return 0; }
    deny_write "$probe_path"
  )
  probe_status=$?
  assert_eq 1 "$probe_status" \
    "$(basename "$probe_path"): a write-through denial is reported to the caller"
  assert_eq "$probe_mode" "$(fixture_mode "$probe_path")" \
    "$(basename "$probe_path"): the original mode remains in place"
  if [ -f "$probe_path" ]; then
    assert_eq "$probe_bytes" "$(cat "$probe_path")" \
      "file: the append probe restores the original bytes"
  else
    assert_eq "" "$(find "$probe_path" -mindepth 1)" \
      "dir: the create probe removes its child"
  fi
done
assert_eq "" "$(find "$TMPROOT" -name 'denied-file.*')" \
  "the write-through probes leave no restore backup behind"

test_case "a first sync copies the spec and both schemas"
t="$(fake_repo)"; a="$(assets_of "$t")"
sync "$t"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'sync-assets: OK' "reports success"
assert_contains "$R_OUT" '2 schema(s)' "counts what it synced"
assert_same "$t/README.md" "$a/README.md" "README.md is identical"
assert_eq "one.xsd
two.xsd" "$(cd "$a/schemas" && ls *.xsd | LC_ALL=C sort)" "the schema sets match"

test_case "a drifted asset README is repaired"
printf 'stale paraphrase\n' > "$a/README.md"
sync "$t"
assert_eq 0 "$R_STATUS" "exits 0"
assert_same "$t/README.md" "$a/README.md" "the copy is current again"

test_case "an orphan asset schema is deleted"
printf '<xsd>ghost</xsd>\n' > "$a/schemas/ghost.xsd"
sync "$t"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$a/schemas/ghost.xsd" "the orphan is gone"

test_case "schema additions and removals at the root are mirrored"
printf '<xsd>three</xsd>\n' > "$t/schemas/three.xsd"
rm "$t/schemas/one.xsd"
sync "$t"
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$a/schemas/three.xsd" "the new schema arrived"
assert_no_file "$a/schemas/one.xsd" "the removed schema left"
assert_eq "three.xsd
two.xsd" "$(cd "$a/schemas" && ls *.xsd | LC_ALL=C sort)" "membership matches the root"

test_case "an unwritable assets directory aborts before the copy"
# This leg is the shell killing the run at the bare `cp` under `set -e`, not
# the script diagnosing anything, so it is pinned as that and nothing more.
# Its old name — "a sync that cannot write fails loudly" — read as coverage of
# the script's own refusals, which are the cases below; the last assertion is
# what stops it standing in for them again (SFT-0049). Making this leg print a
# `sync-assets:` line would be a change to the script, not to this file.
control="$(fake_repo)"; control_assets="$(assets_of "$control")"
sync "$control"
printf '<xsd>new</xsd>\n' > "$control/schemas/new.xsd"
sync "$control"
assert_eq 0 "$R_STATUS" "the writable control reaches the copy and succeeds"
assert_file "$control_assets/schemas/new.xsd" \
  "the writable control proves the new schema would be copied"
t="$(fake_repo)"; a="$(assets_of "$t")"
sync "$t"
printf '<xsd>new</xsd>\n' > "$t/schemas/new.xsd"
schemas_mode="$(fixture_mode "$a/schemas")"
if deny_write "$a/schemas"; then
  sync "$t"
  status=$R_STATUS; out=$R_OUT; err=$R_ERR
  restore_write "$a/schemas"
  assert_eq 1 "$status" "exits 1 — the aborted command's status, not a diagnosed refusal"
  assert_no_file "$a/schemas/new.xsd" "and the schema is genuinely missing"
  assert_not_contains "$out" 'sync-assets: OK' "no clean sync is reported"
  assert_not_contains "$err" 'sync-assets:' \
    "the script itself says nothing here: $(printf '%s' "$err" | head -n 1)"
  assert_eq "$schemas_mode" "$(fixture_mode "$a/schemas")" \
    "the fixture restores the directory mode before the case ends"
else
  skip "sync-assets unwritable-directory abort" \
    "this uid can write through mode 500; the denial probe restored the directory"
fi

test_case "a root without the normative README is refused before any write"
t="$(fake_repo)"; rt="$(cd "$t" && pwd -P)"
rm "$t/README.md"
before="$(tree_digest "$t")"
sync "$t"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" "sync-assets: normative README not found at $rt/README.md" \
  "and names the spec it could not find"
assert_eq "$before" "$(tree_digest "$t")" "with not one byte of the fixture written"

test_case "a root without schemas/ is refused before any write"
t="$(fake_repo)"; rt="$(cd "$t" && pwd -P)"
rm -r "$t/schemas"
before="$(tree_digest "$t")"
sync "$t"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" "sync-assets: normative schemas/ not found at $rt/schemas" \
  "and names the directory it could not find"
assert_eq "$before" "$(tree_digest "$t")" "with not one byte of the fixture written"

test_case "a skill without an assets directory is refused, not created"
# The `mkdir -p "$assets/schemas"` further down could be read as covering this;
# it cannot, because the refusal is above it. tree_digest hashes files only, so
# the directory the failing path would have created is asserted separately.
t="$(fake_repo)"; a="$(assets_of "$t")"; rt="$(cd "$t" && pwd -P)"
rm -r "$a"
before="$(tree_digest "$t")"
sync "$t"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" \
  "sync-assets: skill assets directory not found at $rt/src/skills/sift-init/assets" \
  "and names the assets directory it will not invent"
assert_no_dir "$a" "the refusal creates nothing"
assert_eq "$before" "$(tree_digest "$t")" "with not one byte of the fixture written"
skip "the [ -d \"\$skill\" ] precondition at sync-assets.sh:29" \
  "unreachable: skill is assigned by cd-ing into the script's own parent, so a missing directory aborts that assignment under set -e and the check can only ever be true"

test_case "a relocated skill is copied into once the root guard is removed"
# The positive control tests/README.md requires under "Destructive and
# concurrent sequences": without it, a guard that never ran looks exactly like
# one that held, because the assertion below is "nothing was written".
t="$(relocated_repo)"; skill="$(relocated_card "$t")"
grep -v 'lacks src/skills/sift-init' "$skill/scripts/sync-assets.sh" > "$skill/scripts/unguarded.sh"
run_cmd "$t" bash "$skill/scripts/unguarded.sh"
assert_eq 0 "$R_STATUS" "the copy without the guard runs to completion"
assert_same "$t/README.md" "$skill/assets/README.md" \
  "and writes the foreign root's README over the skill's assets"

test_case "a relocated skill refuses the root it resolved"
t="$(relocated_repo)"; skill="$(relocated_card "$t")"; rt="$(cd "$t" && pwd -P)"
before="$(tree_digest "$t")"
run_cmd "$t" bash "$skill/scripts/sync-assets.sh"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" "sync-assets: resolved root $rt lacks src/skills/sift-init" \
  "and names the root it refused to sync from"
assert_no_file "$skill/assets/README.md" "the foreign README is not copied"
assert_eq "$before" "$(tree_digest "$t")" "with not one byte of the fixture written"

test_case "an incomplete sync is reported as FAIL, with every mismatch named"
t="$(fake_repo)"; a="$(assets_of "$t")"
printf '<xsd>ghost</xsd>\n' > "$a/schemas/ghost.xsd"
shim="$(noop_shim "$(newdir)/shim")"
sync_shimmed "$t" "$shim"
assert_eq 1 "$R_STATUS" "exits 1, the documented drift status"
assert_not_contains "$R_OUT" 'sync-assets: OK' "and reports no clean sync"
assert_contains "$R_ERR" 'sync-assets: missing asset README.md after copy' \
  "the absent README is named"
assert_contains "$R_ERR" 'sync-assets: missing asset schema after copy: one.xsd' \
  "each absent schema is named (one.xsd)"
assert_contains "$R_ERR" 'sync-assets: missing asset schema after copy: two.xsd' \
  "each absent schema is named (two.xsd)"
assert_contains "$R_ERR" 'sync-assets: stale asset schema survived sync: ghost.xsd' \
  "and the orphan that outlived the sync is named"
assert_contains "$R_ERR" 'sync-assets: FAIL — 4 mismatch(es); assets are incomplete' \
  "the verdict counts all four"

test_case "the verdict's count moves with the number of mismatches"
# Asserting the number rather than the word FAIL is what pins the counter as a
# counter: a flag rendering a constant 1 passes the case above and fails here.
t="$(fake_repo)"
rm "$t/schemas/two.xsd"
sync_shimmed "$t" "$shim"
assert_eq 1 "$R_STATUS" "still exits 1"
assert_contains "$R_ERR" 'sync-assets: FAIL — 2 mismatch(es); assets are incomplete' \
  "one missing README and one missing schema make two, not four"

test_case "the skill documents one command and no hand-copying"
skill_md="$(cat "$REAL_CARD/SKILL.md")"
assert_contains "$skill_md" 'src/skills/sift-init/scripts/sync-assets.sh' \
  "SKILL.md names the script"
assert_contains "$skill_md" 'Do not hand-copy' "…and rules out doing it by hand"
maint="$(awk '/^## Maintaining this skill/ { m = 1 } m' "$REAL_CARD/SKILL.md")"
assert_eq 1 "$(printf '%s\n' "$maint" | grep -c 'sync-assets.sh')" \
  "the maintenance section points at exactly one command"
assert_eq 0 "$(printf '%s\n' "$maint" | grep -cE '^[[:space:]]*(cp|diff) ')" \
  "no cp or diff step is documented alongside it"

test_case "the script runs under a stricter POSIX shell too"
# No BSD userland is available here; running the same script under dash is the
# closest available proxy for "does not rely on bash extensions".
t="$(fake_repo)"
R_SHELL=dash sync "$t"
assert_eq 0 "$R_STATUS" "dash accepts and completes it"
assert_same "$t/README.md" "$(assets_of "$t")/README.md" "with the same result"
skip "sync-assets.sh on a real BSD userland" "no BSD host in this environment; the static bans cover the known divergences"

summary
