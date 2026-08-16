#!/usr/bin/env bash
# Lint: syntax and shape of every shell file in the repository.
#
# Nothing here assumes shellcheck is installed — the same rule that governs the
# recipes governs their tooling — so the authoritative lint is the shell's own
# parser plus the conventions the skills rely on: a shebang, an executable bit
# on anything a skill documents as a command, and no CRLF line endings.
# When shellcheck *is* present it is run as an extra, never as a requirement.
#
# Keep the tool's name off the front of a comment line. A comment whose first
# word is that token is read as a directive, a malformed one is SC1073, and an
# SC1073 aborts the parse of the whole file — so the findings below it are never
# reported. That is exactly how the SC2046 on the arm at the bottom of this file
# stayed invisible until SFT-0036: this very paragraph used to open with it.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

shell_files() {
  find "$REPO_ROOT/src" "$REPO_ROOT/tests" -name '*.sh' | LC_ALL=C sort
}

shell_file_list="$(shell_files)"
script_file_list="$(find "$REPO_ROOT/src" -path '*/scripts/*.sh' | LC_ALL=C sort)"
test_file_list="$(find "$REPO_ROOT/tests" -name '*.test.sh' | LC_ALL=C sort)"

test_case "the shell file walks actually read something"
assert_contains "$shell_file_list" "$REPO_ROOT/tests/lib/harness.sh" \
  "shell_files includes its known harness anchor"
assert_contains "$script_file_list" "$REPO_ROOT/src/skills/sift-init/scripts/sift-init.sh" \
  "the skill-script walk includes its known initializer anchor"
assert_contains "$test_file_list" "$REPO_ROOT/tests/static/shell-lint.test.sh" \
  "the test-file walk includes its known shell-lint anchor"

test_case "every shell file parses"
parse_failures="$(for f in $shell_file_list; do
  if err="$(bash -n "$f" 2>&1)"; then
    :
  else
    printf '%s\n%s\n' "${f#"$REPO_ROOT/"}" "$err"
  fi
done)"
assert_eq "" "$parse_failures" "all shell files parse under bash -n"

test_case "every shell file declares an interpreter"
missing_shebangs="$(for f in $shell_file_list; do
  head -n 1 "$f" | grep -q '^#!' \
    || echo "${f#"$REPO_ROOT/"} has no #! line"
done)"
assert_eq "" "$missing_shebangs" "all shell files start with #!"

test_case "documented commands are executable"
not_executable="$(for f in $script_file_list; do
  case "$(basename "$f")" in
    lib.sh) continue ;;   # sourced, never executed
  esac
  [ -x "$f" ] || echo "${f#"$REPO_ROOT/"} is not executable"
done
for f in "$REPO_ROOT/tests/run.sh" $test_file_list; do
  [ -x "$f" ] || echo "${f#"$REPO_ROOT/"} is not executable"
done)"
assert_eq "" "$not_executable" "every skill script and test file is runnable"

test_case "no CRLF line endings"
crlf="$(for f in $shell_file_list "$README"; do
  if grep -lq "$(printf '\r')" "$f" 2>/dev/null; then echo "${f#"$REPO_ROOT/"}"; fi
done)"
assert_eq "" "$crlf" "shell files and the spec are LF-only"

test_case "shellcheck, if the machine happens to have it"
if command -v shellcheck > /dev/null 2>&1; then
  # Collect the list into an array rather than letting an unquoted command
  # substitution split it: shellcheck takes its inputs as separate arguments, and
  # word splitting hands it garbage the first time a repository path holds a
  # blank (SC2046).
  lint_files=()
  while IFS= read -r f; do lint_files+=("$f"); done < <(shell_files)
  out="$(shellcheck -S warning "${lint_files[@]}" 2>&1)" \
    && t_ok "shellcheck reports no warnings" \
    || t_fail "shellcheck reports no warnings" "$(printf '%s\n' "$out" | head -n 20)"
else
  skip "shellcheck pass" "not installed; the convention forbids requiring it"
fi

summary
