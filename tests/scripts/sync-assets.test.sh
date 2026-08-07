#!/usr/bin/env bash
# sync-assets.sh — the one command that keeps the card's assets current (SFT-0006).
#
# Every case runs against a throwaway copy of the card layout, never the real
# repository, because the script's whole job is to write.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

REAL_CARD="$REPO_ROOT/src/skills/sift-init"

# A minimal repository with the card's shape: the script resolves its paths from
# its own location, so the copy must keep src/skills/sift-init/scripts/.
fake_repo() {
  local t card
  t="$(newdir)"
  card="$t/src/skills/sift-init"
  mkdir -p "$card/scripts" "$card/assets/schemas" "$t/schemas"
  cp "$REAL_CARD/scripts/sync-assets.sh" "$card/scripts/"
  printf '# normative spec\n' > "$t/README.md"
  printf '<xsd>one</xsd>\n' > "$t/schemas/one.xsd"
  printf '<xsd>two</xsd>\n' > "$t/schemas/two.xsd"
  printf '%s\n' "$t"
}

sync() { run_cmd "$1" "${R_SHELL:-bash}" "$1/src/skills/sift-init/scripts/sync-assets.sh"; }

assets_of() { printf '%s' "$1/src/skills/sift-init/assets"; }

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

test_case "a sync that cannot write fails loudly"
t="$(fake_repo)"; a="$(assets_of "$t")"
sync "$t"
printf '<xsd>new</xsd>\n' > "$t/schemas/new.xsd"
chmod 500 "$a/schemas"
sync "$t"
status=$R_STATUS; err=$R_ERR
chmod 700 "$a/schemas"
assert_ne 0 "$status" "exits non-zero rather than reporting a clean sync"
assert_no_file "$a/schemas/new.xsd" "and the schema is genuinely missing"
assert_ne "" "$err" "with a diagnostic on stderr: $(printf '%s' "$err" | head -n 1)"

test_case "the card documents one command and no hand-copying"
skill="$(cat "$REAL_CARD/SKILL.md")"
assert_contains "$skill" 'src/skills/sift-init/scripts/sync-assets.sh' \
  "SKILL.md names the script"
assert_contains "$skill" 'Do not hand-copy' "…and rules out doing it by hand"
maint="$(awk '/^## Maintaining this card/ { m = 1 } m' "$REAL_CARD/SKILL.md")"
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
