#!/usr/bin/env bash
# lib.sh — the root and prefix resolution every skill script shares (SFT-0008).
#
# sift-drain and sift-prime each carry a lib.sh, and the top half of the two is
# the same block: resolve the project root, then resolve the prefix. Every case
# below is swept across scripts from BOTH skills, because two
# copies of a contract that drift apart is the failure this file exists to catch
# — a skill that resolves a different root than its sibling allocates IDs into a
# tree the other one cannot see. The sweep runs per SCRIPT rather than per skill:
# the block is one file per skill, but each script has to propagate its refusal,
# and a script that swallowed the exit would be invisible to a per-skill check.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT, and where the upward walk is
# the thing under test, $PWD does. The first case proves no .ai/sift exists above
# TMPROOT, so a walk can never reach the repository running the suite.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"
PRIME="$REPO_ROOT/src/skills/sift-prime/scripts"

# Every script that sources a lib.sh and can be run without writing, with the
# minimum arguments that get it past its own usage check — so the failure under
# test is always the shared block. Both skills' scripts are here; the two that
# write are named in tests/README.md with the reason they cannot join, because a
# sweep asserting a SUCCESSFUL resolution would have to run them for real.
SCRIPTS="$DRAIN/next-ticket.sh:
$DRAIN/wave-status.sh:
$DRAIN/ticket-check.sh:
$DRAIN/list-labels.sh:
$DRAIN/tickets-by-label.sh:caching
$PRIME/reserve-ids.sh:1
$PRIME/existing-work.sh:"

# sweep <description> <workdir> <env-assignment…> -- expectations are asserted by
# the caller-supplied check() function, which sees R_STATUS/R_OUT/R_ERR.
#
# SWEEP_SCRIPT carries the full path of the script that produced them, so a check
# can branch on which SKILL it came from: the block is shared, but not every line
# of its output is, and an assertion that ignores the difference passes on a skill
# that never emits the message it claims to require (SFT-0050).
SWEEP_SCRIPT=''
sweep() {  # sweep <workdir> <check-fn> [env assignments…]
  local dir="$1" check="$2"; shift 2
  local entry script arg
  for entry in $SCRIPTS; do
    script="${entry%%:*}"
    arg="${entry#*:}"
    SWEEP_SCRIPT="$script"
    if [ -n "$arg" ]; then
      run_cmd "$dir" env "$@" "$script" "$arg"
    else
      run_cmd "$dir" env "$@" "$script"
    fi
    "$check" "$(basename "$script")"
  done
}

# --- The sandbox itself ------------------------------------------------------

test_case "no sift tree exists above the temporary tree"
assert_eq "" "$(markers_above "$TMPROOT")" "the upward walk from TMPROOT cannot reach a real sift tree"

# --- SIFT_ROOT ---------------------------------------------------------------

test_case "an unreadable SIFT_ROOT is refused by every script"
root="$(newdir)"
check_unreadable() {
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'SIFT_ROOT is not a readable directory'*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 and names the variable"
  else t_fail "$1 rejects an unreadable SIFT_ROOT" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
sweep "$root" check_unreadable SIFT_ROOT="$root/nowhere"

test_case "a SIFT_ROOT with no tree under it is refused by every script"
# The one place the two copies of the block deliberately differ: sift-prime sends
# the operator to sift-init, because priming an uninitialized repository is a
# thing people try, and sift-drain does not, because a drain with no tree has no
# backlog to have been draining. So the hint is asserted PRESENT on one skill and
# ABSENT on the other — required of both, it would be satisfied by neither skill
# emitting it; required of neither, the one message that tells the two apart
# would be unguarded (SFT-0050).
check_no_tree() {
  local want_hint=0 has_hint=0
  case "$SWEEP_SCRIPT" in */sift-prime/*) want_hint=1 ;; esac
  case "$R_ERR" in *'hint: run sift-init before priming'*) has_hint=1 ;; esac
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'no .ai/sift/ directory under SIFT_ROOT'*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 rather than treating an empty directory as an empty backlog"
  else t_fail "$1 rejects a treeless SIFT_ROOT" "status=$R_STATUS" "stderr=$R_ERR"; fi
  if [ "$has_hint" = "$want_hint" ]; then
    if [ "$want_hint" = 1 ]
    then t_ok "$1 sends the operator to sift-init, as only sift-prime does"
    else t_ok "$1 emits no priming hint: that message belongs to the other skill"; fi
  else
    t_fail "$1 gets the sift-init hint exactly when it is a sift-prime script" \
      "want_hint=$want_hint" "has_hint=$has_hint" "stderr=$R_ERR"
  fi
}
sweep "$root" check_no_tree SIFT_ROOT="$root"

test_case "no tree at or above \$PWD is refused by every script"
check_no_walk() {
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'no .ai/sift/ directory found at or above'*) true ;; *) false ;; esac &&
     case "$R_ERR" in *'set SIFT_ROOT='*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 with the escape hatch in the hint"
  else t_fail "$1 refuses to guess a root" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
sweep "$root" check_no_walk PATH="$PATH"

# --- The upward walk ---------------------------------------------------------

test_case "the walk finds the tree from any depth below it"
root="$(newdir)"
make_tree "$root" ACME
# A bare tree would make next-ticket.sh and wave-status.sh exit 2 on their own
# no-tickets precondition, which is indistinguishable from a failed walk. One
# ticket gives every swept script something real to read, so a 2 here can only
# mean the root was not resolved.
ticket "$root" open v1/bug ACME-0001 alpha 'Alpha' 'labels: [caching]' > /dev/null
mkdir -p "$root/pkg/api/src/deep"
check_found() {
  if [ "$R_STATUS" -ne 2 ]
  then t_ok "$1 resolved the tree from four directories down"
  else t_fail "$1 resolved the tree" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
sweep "$root/pkg/api/src/deep" check_found PATH="$PATH"

test_case "a nested .git does not stop the walk"
# In a monorepo, a subproject's own VCS marker must not shadow the parent's sift
# tree: the .ai/sift DIRECTORY is the marker, and nothing else is.
mkdir "$root/pkg/.git"
run_cmd "$root/pkg/api" env PATH="$PATH" "$DRAIN/ticket-check.sh"
assert_eq 0 "$R_STATUS" "ticket-check.sh still resolves the parent tree"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' "and reads it"

# --- Prefix resolution -------------------------------------------------------

test_case "the configured prefix is what the scripts use"
root="$(newdir)"
make_tree "$root" ACME
ticket "$root" open v1/bug ACME-0001 alpha 'Alpha' 'labels: [caching]' > /dev/null
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/ticket-check.sh"
assert_eq 0 "$R_STATUS" "ticket-check.sh exits 0"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' "it counted the ACME ticket"

test_case "a quoted prefix in config.yaml is unwrapped"
for quoted in '"ACME"' "'ACME'"; do
  printf 'prefix: %s\n' "$quoted" > "$root/.ai/sift/config/config.yaml"
  run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/ticket-check.sh"
  if [ "$R_STATUS" -eq 0 ] &&
     case "$R_OUT" in *'OK: 1 ticket file(s) are consistent'*) true ;; *) false ;; esac
  then t_ok "prefix: $quoted resolves to ACME"
  else t_fail "prefix: $quoted" "status=$R_STATUS" "stdout=$R_OUT"; fi
done
printf 'prefix: ACME\n' > "$root/.ai/sift/config/config.yaml"

test_case "SIFT_PREFIX overrides the configured value"
run_cmd "$root" env SIFT_ROOT="$root" SIFT_PREFIX=ZZZZ "$DRAIN/ticket-check.sh"
# The override has to reach the file glob the whole verdict is built from: with
# PREFIX=ZZZZ the ACME file is not a ticket file, so zero is the consistent
# answer. The case above saw one ticket on the same tree, which is what makes
# this zero evidence the override landed rather than an empty tree.
assert_eq 0 "$R_STATUS" "exits 0: under ZZZZ there is nothing left to be inconsistent about"
assert_contains "$R_OUT" 'OK: 0 ticket file(s) are consistent' \
  "the ACME file stops counting"
run_cmd "$root" env SIFT_ROOT="$root" SIFT_PREFIX=ZZZZ "$PRIME/reserve-ids.sh" 1
assert_eq 0 "$R_STATUS" "reserve-ids.sh exits 0"
assert_eq "ZZZZ-0001" "$R_OUT" "and allocates under the overridden prefix, from both skills' lib.sh"

test_case "with no config the prefix is inferred from the ticket filenames"
rm "$root/.ai/sift/config/config.yaml"
run_cmd "$root" env SIFT_ROOT="$root" "$PRIME/reserve-ids.sh" 1
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$R_OUT" "the majority filename prefix is adopted, and the mark is respected"

test_case "a prefix that cannot be determined at all is an error, not a guess"
root="$(newdir)"
make_tree "$root" ACME
rm "$root/.ai/sift/config/config.yaml"
check_no_prefix() {
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'cannot determine the ticket prefix'*) true ;; *) false ;; esac &&
     case "$R_ERR" in *'export SIFT_PREFIX'*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 with both ways to fix it"
  else t_fail "$1 refuses to guess a prefix" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
sweep "$root" check_no_prefix SIFT_ROOT="$root"

summary
