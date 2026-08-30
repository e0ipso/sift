#!/usr/bin/env bash
# Static analysis: Strikethroo planning and cleanup stay inside approved scope.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

PRE="$REPO_ROOT/.ai/strikethroo/config/hooks/PRE_PLAN.md"
POST="$REPO_ROOT/.ai/strikethroo/config/hooks/POST_EXECUTION.md"

PRE_AUTHORITY='The work order and approved plan are the only scope authority.'
PRE_ERROR='- Include error handling that an acceptance criterion or a contract named by the work'
PRE_SPECULATION='- Exclude speculative failure handling that has no traceable requirement in the work'
COMPATIBILITY='- Preserve, replace, or remove legacy behaviour only when the work order or approved plan'
RETURN_TO_PLAN='- If the work order and approved plan conflict, or a required compatibility decision is'
POST_CLEANUP='Cleanup is limited to touched files and to debt introduced by the approved change or dead'
POST_EXISTING='code that the approved change made obsolete. Do not use cleanup to fix unrelated'

# contract_violations <pre-plan> <post-execution> prints one label per missing
# boundary and per broad rule that used to authorize work outside that boundary.
contract_violations() {
  local pre="$1" post="$2" claim
  while IFS='|' read -r file claim label; do
    grep -Fq -e "$claim" "$file" || printf '%s\n' "$label"
  done <<EOF
$pre|$PRE_AUTHORITY|PRE_PLAN approved authority
$pre|$PRE_ERROR|PRE_PLAN acceptance-required error handling
$pre|$PRE_SPECULATION|PRE_PLAN speculative error boundary
$pre|$COMPATIBILITY|PRE_PLAN declared compatibility
$pre|$RETURN_TO_PLAN|PRE_PLAN return to planning
$post|$PRE_AUTHORITY|POST_EXECUTION approved authority
$post|$POST_CLEANUP|POST_EXECUTION touched-file cleanup boundary
$post|$POST_EXISTING|POST_EXECUTION pre-existing debt boundary
$post|$COMPATIBILITY|POST_EXECUTION declared compatibility
$post|$RETURN_TO_PLAN|POST_EXECUTION return to planning
EOF

  grep -Fq -e "Implementing error handling beyond what's necessary for the core request" "$pre" \
    && printf '%s\n' 'PRE_PLAN broad error-handling prohibition returned'
  grep -Fq -e 'None of those are acceptable. Fix them' "$post" \
    && printf '%s\n' 'POST_EXECUTION broad cleanup authority returned'
  grep -Fq -e 'assume that backwards compatibility layers are tech debt' "$post" \
    && printf '%s\n' 'POST_EXECUTION undeclared compatibility default returned'
  return 0
}

replace_line() {
  local file="$1" want="$2" replacement="$3"
  awk -v want="$want" -v replacement="$replacement" '
    $0 == want { $0 = replacement; changed++ }
    { print }
    END { if (changed != 1) exit 2 }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

test_case "both hooks bind implementation decisions to approved scope"
assert_file "$PRE" "PRE_PLAN exists"
assert_file "$POST" "POST_EXECUTION exists"
assert_eq "" "$(contract_violations "$PRE" "$POST")" \
  "every error-handling, cleanup, and compatibility boundary is present"

test_case "excluding acceptance-required error handling fails the guard"
work="$(newdir)"
pre_copy="$work/PRE_PLAN.md"
post_copy="$work/POST_EXECUTION.md"
cp "$PRE" "$pre_copy"
cp "$POST" "$post_copy"
replace_line "$pre_copy" "$PRE_ERROR" \
  "- Implementing error handling beyond what's necessary for the core request is out of scope."
violations="$(contract_violations "$pre_copy" "$post_copy")"
assert_not_contains "$(cat "$pre_copy")" "$PRE_ERROR" \
  "the required-error rule is absent from the damaged copy"
assert_contains "$violations" "PRE_PLAN acceptance-required error handling" \
  "the comparison reports the missing acceptance rule"
assert_contains "$violations" "PRE_PLAN broad error-handling prohibition returned" \
  "the comparison reports the renewed broad prohibition"

test_case "broad cleanup and compatibility defaults fail the guard"
work="$(newdir)"
pre_copy="$work/PRE_PLAN.md"
post_copy="$work/POST_EXECUTION.md"
cp "$PRE" "$pre_copy"
cp "$POST" "$post_copy"
replace_line "$post_copy" "$POST_CLEANUP" \
  "Assess whether the plan left tech debt or dead code. None of those are acceptable. Fix them."
replace_line "$post_copy" "$COMPATIBILITY" \
  "- Unless the plan says otherwise, assume that backwards compatibility layers are tech debt."
violations="$(contract_violations "$pre_copy" "$post_copy")"
assert_not_contains "$(cat "$post_copy")" "$POST_CLEANUP" \
  "the touched-file cleanup rule is absent from the damaged copy"
assert_not_contains "$(cat "$post_copy")" "$COMPATIBILITY" \
  "the declared-compatibility rule is absent from the damaged copy"
assert_contains "$violations" "POST_EXECUTION touched-file cleanup boundary" \
  "the comparison reports cleanup outside touched files"
assert_contains "$violations" "POST_EXECUTION declared compatibility" \
  "the comparison reports the missing compatibility rule"
assert_contains "$violations" "POST_EXECUTION broad cleanup authority returned" \
  "the comparison reports the renewed broad cleanup rule"
assert_contains "$violations" "POST_EXECUTION undeclared compatibility default returned" \
  "the comparison reports the renewed compatibility default"

summary
