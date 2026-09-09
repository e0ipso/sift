#!/usr/bin/env bash
# Bounded, lossless reads and stage-specific Markdown extraction.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
READ="$REPO_ROOT/src/skills/sift-drain/scripts/read-context.sh"

test_case "pages bound long output without losing content"
d="$(newdir)"; source_file="$d/long file.md"
awk 'BEGIN { for (i = 0; i < 19000; i++) printf "x"; print "" }' > "$source_file"
: > "$d/rebuilt"
for page in 1 2 3; do
  "$READ" "$source_file" --all "$page" > "$d/page"
  assert_eq 0 "$?" "page $page succeeds"
  bytes=$(wc -c < "$d/page" | tr -d ' ')
  [ "$bytes" -le 8050 ] && t_ok "page $page is bounded" || t_fail "page $page is bounded" "$bytes bytes"
  sed '1d' "$d/page" >> "$d/rebuilt"
done
assert_contains "$(head -n 1 "$d/page")" 'next: none' "last page explicitly ends the read"
cmp -s "$source_file" "$d/rebuilt" && t_ok 'all bytes survive pagination' || t_fail 'all bytes survive pagination' 'content differs'
run_cmd "$d" "$READ" "$source_file" --all 4
assert_eq 4 "$R_STATUS" "out-of-range page fails rather than pretending to be an empty read"
printf 'no trailing newline' > "$d/unterminated"
"$READ" "$d/unterminated" --all > "$d/page"
sed '1d' "$d/page" > "$d/rebuilt"
assert_same "$d/unterminated" "$d/rebuilt" "an unterminated last line remains unterminated"

test_case "UTF-8 characters stay whole at a page boundary"
awk 'BEGIN { for (i = 0; i < 7999; i++) printf "x" }' > "$d/utf8"
printf '\303\251\n' >> "$d/utf8"
"$READ" "$d/utf8" --all 1 > "$d/page1"
"$READ" "$d/utf8" --all 2 > "$d/page2"
assert_eq 7999 "$(sed '1d' "$d/page1" | wc -c | tr -d ' ')" "first page stops before a split character"
sed '1d' "$d/page1" > "$d/rebuilt"
sed '1d' "$d/page2" >> "$d/rebuilt"
cmp -s "$d/utf8" "$d/rebuilt" && t_ok 'UTF-8 content survives' || t_fail 'UTF-8 content survives' 'content differs'

test_case "a selected section excludes future stages and keeps fenced headings"
cat > "$d/stages.md" <<'EOF'
# Stages
Preamble only.
## Intake
Current stage.
```
## Gate
This is an example, not a stage boundary.
```
## Gate
Future-stage sentinel.
EOF
run_cmd "$d" "$READ" "$d/stages.md" '## Intake'
assert_eq 0 "$R_STATUS" "section read succeeds"
assert_contains "$R_OUT" 'Current stage.' "requested content is present"
assert_contains "$R_OUT" 'This is an example' "fenced heading does not terminate the section"
assert_not_contains "$R_OUT" 'Future-stage sentinel.' "later stage is not loaded"
run_cmd "$d" "$READ" "$d/stages.md" --preamble
assert_contains "$R_OUT" 'Preamble only.' "preamble is independently readable"
assert_not_contains "$R_OUT" 'Current stage.' "preamble does not preload stages"
run_cmd "$d" "$READ" "$d/stages.md" '## Absent'
assert_eq 3 "$R_STATUS" "missing section is explicit failure"
assert_eq '' "$R_OUT" "missing section does not return unrelated text"
run_cmd "$d" "$READ" "$d/stages.md" --all invalid
assert_eq 2 "$R_STATUS" "invalid page fails"

test_case "bounded failure excerpts preserve the raw verification log and exit code"
log="$d/verification.log"
if bash -c 'awk '\''BEGIN { for (i=0; i<1000; i++) print "failure detail" }'\''; exit 7' > "$log" 2>&1; then
  result=0
else
  result=$?
fi
assert_eq 7 "$result" "logging preserves the verifier failure"
before=$(cksum < "$log")
run_cmd "$d" "$READ" "$log" --all 1
assert_contains "$R_OUT" 'next: 2' "large failure output has an explicit continuation"
assert_eq "$before" "$(cksum < "$log")" "reading an excerpt leaves full raw evidence on disk"

summary
