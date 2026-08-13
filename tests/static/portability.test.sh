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
# The claim is about the COLLECTOR — that both of its two sources reached the
# corpus — so it is asserted on the tags the collector itself writes rather than
# on a line either source happens to hold today. A reworded recipe or a renamed
# helper changes neither count; a collector that stopped reading one of the two
# drops that count to zero, which is the only failure this case is for.
assert_ne 0 "$(printf '%s\n' "$CODE" | wc -l | tr -d ' ')" "code lines were collected"
assert_ne 0 "$(printf '%s\n' "$CODE" | grep -c '^README\.md:')" \
  "README recipes are in scope"
assert_ne 0 "$(printf '%s\n' "$CODE" | grep -c '^src/.*\.sh:')" \
  "shipped scripts are in scope"

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
# It also requires the contents not to open with `--`, which is a usage line's
# optional long option (`[--include-blocked]`) and never a glob: a range whose
# low end is `-` is not something anyone writes on purpose. A single leading
# hyphen still counts, because `[-a-z]` is the idiomatic way to fold a literal
# hyphen into a real character set and must stay covered.
ranges="$(printf '%s\n' "$CODE" \
  | grep -vE '(sed|grep|awk|expr|tr)[[:space:]]' \
  | grep -E '\[!?(-?[A-Za-z0-9_])([A-Za-z0-9_-]*[A-Za-z])?-[A-Za-z][A-Za-z0-9_-]*\]' || true)"
if [ -z "$ranges" ]; then t_ok "validation patterns spell their character sets out"
else t_fail "validation patterns spell their character sets out" \
  "$(printf '%s\n' "$ranges" | head -n 5)"; fi

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

test_case "the BSD half of the promise, and why nothing here can execute it"
# The standing blind spot, recorded where it is measured rather than only in
# tests/README.md. Half the portability promise is about a userland no machine
# in the Linux GitHub Actions job or the dev container runs, so no case in this
# suite can execute a BSD sed, awk or xargs; the bans above are the whole of that
# coverage, and they are a textual proxy for it. Faking a BSD run — aliasing a
# name, asserting against a transcript — would convert an honest gap into a
# false green, so the gap is declared instead. Closing it needs a BSD runner in
# CI, not another assertion.
skip "recipe execution on a real BSD userland" \
  "no BSD host in Linux GitHub Actions CI or the dev container; the bans above are the static proxy"

summary
