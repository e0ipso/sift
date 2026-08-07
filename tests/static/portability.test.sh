#!/usr/bin/env bash
# Static analysis: the portability bans AGENTS.md declares outright.
#
# Three constructs break silently on exactly one of the two userlands the
# convention supports, so they are banned rather than reviewed:
#   sed -i        BSD sed eats the script as a backup suffix
#   xargs -r      a GNU extension older BSD xargs rejects
#   [ \t] in awk  POSIX leaves a backslash in a bracket expression undefined,
#                 so a strict awk reads it as {space, \, t} and eats the
#                 leading "t" of a title like "tenant caching"
# A fourth is a locale trap rather than a userland one: a glob bracket range is
# collated, so under a UTF-8 locale [a-z] also matches B..Z and a validation
# case that spells a range accepts what it meant to reject.
#
# Scope is executable text only — README.md's fenced blocks and the shipped
# shell scripts, comments excluded. The prose that explains a ban necessarily
# names it, and the schemas are XSD regexes, not shell.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

# Every fenced block in README.md, flattened, with source line numbers.
readme_code() {
  awk '/^```/ { inb = !inb; next } inb { printf "README.md:%d: %s\n", NR, $0 }' "$README"
}

# Every shipped shell script, comments and shebangs stripped.
script_code() {
  find "$REPO_ROOT/src" -name '*.sh' | LC_ALL=C sort | while read -r f; do
    awk -v n="${f#"$REPO_ROOT/"}" \
      '{ line = $0; sub(/^[[:space:]]+/, "", line); if (line ~ /^#/) next
         printf "%s:%d: %s\n", n, NR, $0 }' "$f"
  done
}

all_code() { readme_code; script_code; }

CODE="$(all_code)"

test_case "the static scan actually reads something"
assert_ne 0 "$(printf '%s\n' "$CODE" | wc -l | tr -d ' ')" "code lines were collected"
assert_contains "$CODE" 'find .ai/sift -name' "README recipes are in scope"
assert_contains "$CODE" 'prefix_is_well_formed' "shipped scripts are in scope"

banned() {  # banned <description> <extended-regex>
  local hits
  hits="$(printf '%s\n' "$CODE" | grep -E "$2" || true)"
  if [ -z "$hits" ]; then t_ok "$1"
  else t_fail "$1" "$(printf '%s\n' "$hits" | head -n 5)"; fi
}

test_case "banned constructs appear in no executable line"
banned "no sed -i anywhere in runnable text" 'sed[[:space:]]+-i'
banned "no xargs -r anywhere in runnable text" 'xargs[[:space:]]+.*-r'
banned "no [ \\t] bracket expression" '\[ \\t\]'

test_case "no collated bracket range in a glob or case pattern"
# A letter range inside a regex handed to sed/grep/awk is a different animal
# from one in a shell glob: the shell pattern is the one that decides whether a
# value is accepted, and that is the decision a locale must not be able to flip.
# The pattern below deliberately requires a *closed* bracket expression whose
# contents are nothing but set characters, so a test like `[ "${1:-}" = "--x" ]`
# — brackets around a comparison, hyphens in a flag — is not mistaken for one.
ranges="$(printf '%s\n' "$CODE" \
  | grep -vE '(sed|grep|awk|expr|tr)[[:space:]]' \
  | grep -E '\[!?[A-Za-z0-9_-]*[A-Za-z]-[A-Za-z][A-Za-z0-9_-]*\]' || true)"
if [ -z "$ranges" ]; then t_ok "validation patterns spell their character sets out"
else t_fail "validation patterns spell their character sets out" \
  "$(printf '%s\n' "$ranges" | head -n 5)"; fi

test_case "the initializer's own validation sets are spelled out"
init="$REPO_ROOT/src/skills/sift-init/scripts/sift-init.sh"
assert_contains "$(cat "$init")" '[!ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]' \
  "the prefix set is an explicit list"
assert_contains "$(cat "$init")" '[!abcdefghijklmnopqrstuvwxyz0123456789-]' \
  "the milestone set is an explicit list"

test_case "optional binaries are guarded, never assumed"
# xmllint is the only optional tool the convention mentions; every block or
# script that invokes it must first prove it is installed.
for block in $(awk '/^```/ { inb = !inb; if (inb) b++; next } inb && /xmllint/ { print b }' \
                 "$README" | sort -u); do
  text="$(awk -v want="$block" '/^```/ { inb = !inb; if (inb) b++; next } inb && b == want' "$README")"
  assert_contains "$text" 'command -v xmllint' "README block $block guards xmllint"
done
for f in $(printf '%s\n' "$(script_code)" | grep 'xmllint' | cut -d: -f1 | sort -u); do
  assert_contains "$(cat "$REPO_ROOT/$f")" 'command -v xmllint' "$f guards xmllint"
done

summary
