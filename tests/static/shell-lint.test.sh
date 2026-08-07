#!/usr/bin/env bash
# Lint: syntax and shape of every shell file in the repository.
#
# shellcheck is not assumed to be installed — the same rule that governs the
# recipes governs their tooling — so the authoritative lint is the shell's own
# parser plus the conventions the cards rely on: a shebang, an executable bit
# on anything a card documents as a command, and no CRLF line endings.
# When shellcheck *is* present it is run as an extra, never as a requirement.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

shell_files() {
  find "$REPO_ROOT/src" "$REPO_ROOT/tests" -name '*.sh' | LC_ALL=C sort
}

test_case "every shell file parses"
count=0
for f in $(shell_files); do
  count=$((count + 1))
  if err="$(bash -n "$f" 2>&1)"; then :; else t_fail "bash -n ${f#"$REPO_ROOT/"}" "$err"; fi
done
t_ok "$count shell files parse under bash -n"

test_case "every shell file declares an interpreter"
for f in $(shell_files); do
  head -n 1 "$f" | grep -q '^#!' \
    || t_fail "shebang" "${f#"$REPO_ROOT/"} has no #! line"
done
t_ok "all shell files start with #!"

test_case "documented commands are executable"
for f in $(find "$REPO_ROOT/src" -path '*/scripts/*.sh' | LC_ALL=C sort); do
  case "$(basename "$f")" in
    lib.sh) continue ;;   # sourced, never executed
  esac
  [ -x "$f" ] || t_fail "executable bit" "${f#"$REPO_ROOT/"} is not executable"
done
for f in "$REPO_ROOT/tests/run.sh" $(find "$REPO_ROOT/tests" -name '*.test.sh'); do
  [ -x "$f" ] || t_fail "executable bit" "${f#"$REPO_ROOT/"} is not executable"
done
t_ok "every card script and test file is runnable"

test_case "no CRLF line endings"
crlf="$(for f in $(shell_files) "$README"; do
  if grep -lq "$(printf '\r')" "$f" 2>/dev/null; then echo "${f#"$REPO_ROOT/"}"; fi
done)"
assert_eq "" "$crlf" "shell files and the spec are LF-only"

test_case "shellcheck, if the machine happens to have it"
if command -v shellcheck > /dev/null 2>&1; then
  out="$(shellcheck -S warning $(shell_files) 2>&1)" \
    && t_ok "shellcheck reports no warnings" \
    || t_fail "shellcheck reports no warnings" "$(printf '%s\n' "$out" | head -n 20)"
else
  skip "shellcheck pass" "not installed; the convention forbids requiring it"
fi

summary
