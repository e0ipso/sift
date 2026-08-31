#!/usr/bin/env bash
# Skill copies shipped to more than one harness are mirrors, not forks. Every
# directory under .agents/skills with a .cursor/skills counterpart must match
# it file for file and byte for byte, in both directions. The regression this
# pins is the class convention-assets.test.sh documents for the sift-init
# assets: an edit that lands in one copy leaves the other harness running a
# silently divergent skill, and no diff or review ever shows it.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

AGENTS="$REPO_ROOT/.agents/skills"
CURSOR="$REPO_ROOT/.cursor/skills"

# mirror_pairs <agents-root> <cursor-root> — every skill directory name present
# under both roots. A directory present on one side only is a single-harness
# skill, not a mirror, and stays out of scope.
mirror_pairs() {
  local a="$1" c="$2" d name
  for d in "$a"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ -d "$c/$name" ] && printf '%s\n' "$name"
  done
}

# mirror_errors <agents-root> <cursor-root> — one line per missing or divergent
# file across every pair. The set comparison runs in both directions on
# purpose: a one-way sweep never sees a file withdrawn from the side it walks.
mirror_errors() {
  local a="$1" c="$2" name rel
  mirror_pairs "$a" "$c" | while IFS= read -r name; do
    [ -n "$name" ] || continue
    ( cd "$a/$name" && find . -type f | LC_ALL=C sort ) | while IFS= read -r rel; do
      [ -f "$c/$name/$rel" ] ||
        printf '%s/%s: missing from .cursor/skills\n' "$name" "${rel#./}"
    done
    ( cd "$c/$name" && find . -type f | LC_ALL=C sort ) | while IFS= read -r rel; do
      if [ -f "$a/$name/$rel" ]; then
        cmp -s "$a/$name/$rel" "$c/$name/$rel" ||
          printf '%s/%s: differs between the harness copies\n' "$name" "${rel#./}"
      else
        printf '%s/%s: missing from .agents/skills\n' "$name" "${rel#./}"
      fi
    done
  done
}

count_lines() {
  awk 'NF { count++ } END { print count + 0 }'
}

test_case "the harness roots share at least one mirrored skill"
pairs="$(mirror_pairs "$AGENTS" "$CURSOR")"
pair_count="$(printf '%s\n' "$pairs" | count_lines)"
assert_ne 0 "$pair_count" "an empty pair list would make every later check vacuous"

test_case "every mirrored skill is byte-identical across harnesses"
assert_eq "" "$(mirror_errors "$AGENTS" "$CURSOR")" \
  "all $pair_count mirrored skills agree file for file"

# --- Negative controls: each arm of the comparison, driven once --------------

fixture() {  # fixture <dir> — copy both roots so damage never touches the repo
  cp -R "$AGENTS" "$1/agents" && cp -R "$CURSOR" "$1/cursor"
}

victim="$(printf '%s\n' "$pairs" | head -n 1)"
victim_file="$( (cd "$AGENTS/$victim" && find . -type f | LC_ALL=C sort) | head -n 1)"
victim_file="${victim_file#./}"

test_case "a divergent byte in one copy is reported"
work="$(newdir)"
fixture "$work"
printf 'drift\n' >> "$work/agents/$victim/$victim_file"
cmp -s "$work/agents/$victim/$victim_file" "$work/cursor/$victim/$victim_file" && \
  t_fail "the copies differ before the guard runs" "damage did not apply"
assert_contains "$(mirror_errors "$work/agents" "$work/cursor")" \
  "$victim/$victim_file: differs between the harness copies" \
  "the divergent file is named"

test_case "a file withdrawn from the cursor copy is reported"
work="$(newdir)"
fixture "$work"
rm "$work/cursor/$victim/$victim_file"
assert_contains "$(mirror_errors "$work/agents" "$work/cursor")" \
  "$victim/$victim_file: missing from .cursor/skills" \
  "the withdrawal is reported from the agents walk"

test_case "a file withdrawn from the agents copy is reported"
work="$(newdir)"
fixture "$work"
rm "$work/agents/$victim/$victim_file"
assert_contains "$(mirror_errors "$work/agents" "$work/cursor")" \
  "$victim/$victim_file: missing from .agents/skills" \
  "the withdrawal is reported from the cursor walk"

summary
