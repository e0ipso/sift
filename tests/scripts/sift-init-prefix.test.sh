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
newline="$(printf 'A\nB')"
for p in 'A' '1AB' 'ABC!' 'ABC!;rm' 'AB-C' 'AB C' 'abc' 'ABc' 'ÄB' "$newline"; do
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

test_case "a lowercase prefix is rejected under a UTF-8 locale too"
# [A-Z] is collated: under en_US.UTF-8 the order is aAbBcC…zZ, so a range would
# accept 'abc' on exactly the machines the range was meant to be portable to.
# Driven from the matrix axis and its availability guard rather than a third
# hardcoded copy of the names: a locale the machine lacks would otherwise run
# here under a libc fallback to C, asserting nothing about UTF-8 collation
# (SFT-0046).
for loc in $matrix_locales; do
  locale_available "$loc" || continue
  for p in abc ABc; do
    root="$(newdir)"
    R_LOCALE="$loc" init_prefix "$root" "$p"
    if [ "$R_STATUS" -eq 2 ] && [ ! -e "$root/.ai" ]
    then t_ok "'$p' rejected under LC_ALL=$loc"
    else t_fail "'$p' rejected under LC_ALL=$loc" "status=$R_STATUS" "stderr=$R_ERR"; fi
  done
done
# R_LOCALE is an input global read by run_cmd in tests/lib/harness.sh, so no
# reader for it exists in this file. The reset is load-bearing: without it every
# case below this loop would keep running under en_US.utf8.
# shellcheck disable=SC2034
R_LOCALE=C

# --- The destructive sequence, run for real (SFT-0008) -----------------------
#
# `ABC!;rm` is already in the rejection loop above, and the refusal is read off
# stderr. What that never establishes is whether the payload was dangerous: a
# canary nobody ever pointed a weapon at proves nothing about the guard. These
# two cases fire the payload for real inside a throwaway sandbox — first
# unguarded, so the deletion is observed happening, then through sift-init.sh,
# so the refusal is observed preventing the same deletion.

test_case "the payload a metacharacter prefix carries really does delete"
# The positive control. The prefix is written into config.yaml and every later
# recipe builds a glob or a regex out of it, so the whole reason the character
# set is closed is that a value reaching that far is a value someone will
# eventually expand. Expanded once, this one runs its own command.
s="$(newdir)"; mkdir -p "$s/repo"
: > "$s/canary"
payload="AB;rm -f $s/canary"
( eval "printf '%s\n' $payload" ) > /dev/null 2>&1
assert_no_file "$s/canary" "expanded unquoted, the prefix executes the command riding on it"

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
