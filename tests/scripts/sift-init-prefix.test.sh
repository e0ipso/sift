#!/usr/bin/env bash
# sift-init.sh --prefix and --suggest-prefix (SFT-0002).
#
# The prefix is baked into every ticket ID, filename, cross-reference, glob and
# regex downstream, and it is immutable for the life of the repository, so the
# WHOLE value is validated before anything is written. The regression this pins
# is a check that looked at three characters only: `ABC!;rm` reached
# config.yaml, and the metacharacters became every later recipe's problem.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

INIT="$REPO_ROOT/src/skills/sift-init/scripts/sift-init.sh"
MALFORMED='prefix must be 2-8 uppercase alphanumerics starting with a letter'

init_prefix() { run_cmd "$1" "$INIT" --root "$1" --prefix "$2"; }

test_case "accepted prefixes are written to config.yaml"
for p in AB ABCDEFGH A1 SFT; do
  root="$(newdir)"
  init_prefix "$root" "$p"
  if [ "$R_STATUS" -eq 0 ] && grep -q "^prefix: $p\$" "$root/.ai/sift/config/config.yaml"
  then t_ok "'$p' is accepted and configured"
  else t_fail "'$p' is accepted" "status=$R_STATUS" "stderr=$R_ERR"; fi
done

test_case "rejected prefixes never reach a mkdir"
# One row per branch, not one per spelling (SFT-0075). 'A' and '1AB' are the two
# distinct ways the [A-Z]?* accept arm fails — no second character, and no
# leading letter — and are not interchangeable. 'AB-C' is the single
# punctuation-or-space row: the shell-metacharacter spellings it stands for
# (ABC!, ABC!;rm, AB C) are driven end to end, canary and all, by the payload
# case further down. 'abc' and 'ÄB' are the collation claim constraint 1 of
# SFT-0075 keeps: they are why the arm spells its character list out instead of
# writing [A-Z0-9]. 'ABc', the other half of that claim, is driven by the locale
# loop below under a collated matcher with this loop's own two assertions, so it
# is not repeated here.
newline="$(printf 'A\nB')"
for p in 'A' '1AB' 'AB-C' 'abc' 'ÄB' "$newline"; do
  root="$(newdir)"
  init_prefix "$root" "$p"
  label="$(printf '%s' "$p" | tr '\n' '~')"
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *"$MALFORMED"*) true ;; *) false ;; esac &&
     [ ! -e "$root/.ai" ]
  then t_ok "'$label' exits 2 with a diagnostic and no .ai/ directory"
  else t_fail "'$label' is rejected" "status=$R_STATUS" "stderr=$R_ERR"; fi
done

test_case "an over-long prefix gets the length message, not the character-set one"
root="$(newdir)"
init_prefix "$root" ABCDEFGHI
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" 'prefix must be at most 8 characters: ABCDEFGHI' "names the real problem"
assert_not_contains "$R_ERR" "$MALFORMED" "does not misreport the character set"
assert_no_dir "$root/.ai" "nothing was written"

test_case "an omitted or empty prefix keeps its own message"
for args in omitted empty; do
  root="$(newdir)"
  case "$args" in
    omitted) run_cmd "$root" "$INIT" --root "$root" ;;
    empty)   run_cmd "$root" "$INIT" --root "$root" --prefix '' ;;
  esac
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'--prefix is required (use --suggest-prefix for a default)'*) true ;; *) false ;; esac
  then t_ok "$args --prefix asks for one instead of complaining about its shape"
  else t_fail "$args --prefix" "status=$R_STATUS" "stderr=$R_ERR"; fi
done

test_case "a lowercase prefix is rejected under a UTF-8 locale with collated ranges"
# [A-Z] is collated: under en_US.UTF-8 the order is aAbBcC…zZ, so a range would
# accept 'ABc' on exactly the machines the range was meant to be portable to.
# Driven from the matrix axis and its availability guard rather than a third
# hardcoded copy of the names: a locale the machine lacks would otherwise run
# here under a libc fallback to C, asserting nothing about UTF-8 collation
# (SFT-0046).
#
# A locale switch alone proves nothing on bash 5.0+, where globasciiranges is
# enabled by default and a range is compared by ASCII code whatever LC_ALL says
# — which is why this case ran green against a `[A-Z0-9]`/`[A-Z]` mutant until
# SFT-0080. Clear the option explicitly to reproduce the matcher stock macOS
# bash 3.2 uses, the shell the explicit character lists exist for.
#
# 'ABc' is the fixture, not 'abc': under aAbBcC…zZ collation 'a' sorts BEFORE
# 'A', so a leading lowercase letter falls outside [A-Z] in every locale and
# cannot tell a range from the explicit list. Every other row of the rejection
# matrix above is settled before the character class or contains a character
# outside a collated A..Z anywhere. Both verdicts are asserted under the same
# locale and the same matcher, because a validator that rejected everything
# would satisfy the refusal half on its own.
for loc in $matrix_locales; do
  locale_available "$loc" || continue

  root="$(newdir)"
  R_LOCALE="$loc" run_cmd "$root" bash +O globasciiranges "$INIT" \
    --root "$root" --prefix ABc
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *"$MALFORMED"*) true ;; *) false ;; esac &&
     [ ! -e "$root/.ai" ]
  then t_ok "'ABc' rejected under LC_ALL=$loc with globasciiranges disabled"
  else t_fail "'ABc' was accepted under LC_ALL=$loc with globasciiranges disabled" \
    "status=$R_STATUS" "stderr=$R_ERR"; fi

  root="$(newdir)"
  R_LOCALE="$loc" run_cmd "$root" bash +O globasciiranges "$INIT" \
    --root "$root" --prefix ABC
  if [ "$R_STATUS" -eq 0 ] && grep -q '^prefix: ABC$' "$root/.ai/sift/config/config.yaml"
  then t_ok "'ABC' accepted under LC_ALL=$loc with globasciiranges disabled"
  else t_fail "'ABC' accepted under LC_ALL=$loc with globasciiranges disabled" \
    "status=$R_STATUS" "stderr=$R_ERR"; fi
done
# R_LOCALE is an input global read by run_cmd in tests/lib/harness.sh, so no
# reader for it exists in this file. The reset is load-bearing: without it every
# case below this loop would keep running under en_US.utf8.
# shellcheck disable=SC2034
R_LOCALE=C

# --- A metacharacter payload is refused (SFT-0008) ---------------------------
#
# `ABC!;rm` is already in the rejection loop above, and the refusal is read off
# stderr. This case drives that metacharacter-bearing value through sift-init.sh
# inside a throwaway sandbox and proves the rejected prefix cannot reach the
# generated tree or alter the neighbouring canary.

test_case "sift-init.sh refuses it, and the canary is still there"
s="$(newdir)"; mkdir -p "$s/repo"
: > "$s/canary"
before="$(tree_digest "$s")"
run_cmd "$s/repo" "$INIT" --root "$s/repo" --prefix "AB;rm -f $s/canary"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" "$MALFORMED" "naming the character set as the problem"
assert_file "$s/canary" "the file the payload names survives"
assert_no_dir "$s/repo/.ai" "no tree was built to carry the value downstream"
assert_eq "$before" "$(tree_digest "$s")" "and the whole sandbox is byte-identical"

# --- --suggest-prefix --------------------------------------------------------

suggest() {  # suggest <directory basename>
  local parent root
  parent="$(newdir)"
  root="$parent/$1"
  mkdir -p "$root"
  run_cmd "$parent" "$INIT" --suggest-prefix --root "$root"
}

test_case "a usable basename is suggested, an unusable one is refused"
suggest 'my-project'
assert_eq 0 "$R_STATUS" "exits 0 for my-project"
assert_eq "MYPR" "$R_OUT" "strips punctuation, uppercases, first four characters"

for base in 'a' '...' '9lives'; do
  suggest "$base"
  if [ "$R_STATUS" -eq 1 ] && [ -z "$R_OUT" ]
  then t_ok "'$base' yields nothing usable: exit 1, no output, so the card must ask"
  else t_fail "'$base' is refused" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "--suggest-prefix writes nothing"
parent="$(newdir)"; root="$parent/proj"; mkdir -p "$root"
run_cmd "$parent" "$INIT" --suggest-prefix --root "$root"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_dir "$root/.ai" "no tree was materialised by a question"

summary
