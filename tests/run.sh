#!/usr/bin/env bash
# run.sh — the sift test suite. No framework, no runtime, no installed binary.
#
# Usage:
#   tests/run.sh                 every group
#   tests/run.sh static          one or more groups: cookbook scripts static e2e
#   SIFT_TEST_VERBOSE=1 tests/run.sh    stream each file's assertions
#   SIFT_TEST_KEEP=1 tests/run.sh       leave temporary fixtures on disk
#
# Groups:
#   cookbook  README.md recipes run against throwaway trees
#   scripts   the shipped workflow scripts through their command-line interfaces
#   static    portability bans and shell lint (the repository's static analysis)
#   e2e       one full init → allocate → archive → roadmap-check lifecycle
#
# Exit codes: 0 all green | 1 failures.

set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
groups="${*:-cookbook scripts static e2e}"

files=''
for g in $groups; do
  [ -d "$here/$g" ] || { echo "run.sh: no such group: $g" >&2; exit 2; }
  for f in "$here/$g"/*.test.sh; do
    [ -f "$f" ] || continue
    files="$files $f"
  done
done

total_tests=0; total_asserts=0; total_fails=0; total_skips=0; failed_files=''
run_narrowed=''; run_skips=''
start=$(date +%s)

for f in $files; do
  out="$("$f" 2>&1)"
  status=$?
  line="$(printf '%s\n' "$out" | awk '/^# SUMMARY/ { s = $0 } END { print s }')"
  # "printed no summary" is its own state, not a summary of zeros: the defaults
  # below cannot tell the two apart, and a file that exits 0 having run nothing
  # would otherwise be reported as a passing file with no cases (SFT-0045).
  nosummary=''
  [ -n "$line" ] || nosummary=1
  t=$(printf '%s\n' "$line" | sed -n 's/.*tests=\([0-9]*\).*/\1/p')
  a=$(printf '%s\n' "$line" | sed -n 's/.*assertions=\([0-9]*\).*/\1/p')
  fl=$(printf '%s\n' "$line" | sed -n 's/.*failures=\([0-9]*\).*/\1/p')
  sk=$(printf '%s\n' "$line" | sed -n 's/.*skipped=\([0-9]*\).*/\1/p')
  : "${t:=0}"; : "${a:=0}"; : "${fl:=0}"; : "${sk:=0}"

  # These are named degradation records, not assertions. Normalise skip()'s
  # TAP prefix so PASS and FAIL render the same record, while leaving the full
  # assertion stream behind SIFT_TEST_VERBOSE.
  records="$(printf '%s\n' "$out" | awk '
    /^# NARROWED / { print; next }
    /^ok [0-9][0-9]* - # SKIP / { sub(/^ok [0-9][0-9]* - /, ""); print }
  ')"
  narrowed="$(printf '%s\n' "$records" | awk '/^# NARROWED /')"
  skips="$(printf '%s\n' "$records" | awk '/^# SKIP /')"
  run_narrowed="$run_narrowed
$narrowed"
  run_skips="$run_skips
$skips"

  if [ "$fl" -eq 0 ] && { [ "$status" -ne 0 ] || [ -n "$nosummary" ]; }; then
    fl=1   # the file died, or never reported at all; count it as one failure
  fi

  total_tests=$((total_tests + t))
  total_asserts=$((total_asserts + a))
  total_fails=$((total_fails + fl))
  total_skips=$((total_skips + sk))

  rel="${f#"$here/"}"
  if [ "$status" -eq 0 ] && [ "$fl" -eq 0 ]; then
    printf 'PASS  %-44s %3s tests %4s assertions %s skipped\n' "$rel" "$t" "$a" "$sk"
    [ -z "$records" ] || printf '%s\n' "$records" | sed 's/^/      /'
    [ -n "${SIFT_TEST_VERBOSE:-}" ] && printf '%s\n' "$out"
  else
    printf 'FAIL  %-44s %3s tests %4s assertions %s failures\n' "$rel" "$t" "$a" "$fl"
    # Said explicitly, because the dump below is empty for a file that printed
    # nothing — FAIL with no visible cause sends the operator looking elsewhere.
    [ -z "$nosummary" ] || printf '      %s printed no # SUMMARY line\n' "$rel"
    [ -z "$records" ] || printf '%s\n' "$records" | sed 's/^/      /'
    printf '%s\n' "$out" | awk '!/^ok / && !/^# NARROWED /' | sed 's/^/      /'
    failed_files="$failed_files $rel"
  fi
done

narrowed_summary="$(printf '%s\n' "$run_narrowed" | sed -n 's/^# NARROWED //p' \
  | LC_ALL=C sort -u | awk 'NF { if (n++) printf "; "; printf "%s", $0 } END { if (!n) printf "none" }')"
skip_summary="$(printf '%s\n' "$run_skips" | awk '
  /^# SKIP / {
    reason = $0
    sub(/^.* \(/, "", reason)
    sub(/\)$/, "", reason)
    print reason
  }
' | LC_ALL=C sort -u | awk 'NF { if (n++) printf "; "; printf "%s", $0 } END { if (!n) printf "none" }')"

echo
printf 'TOTAL %s test files: %s tests, %s assertions, %s failures, %s skipped (%ss); NARROWED: %s; SKIP reasons: %s\n' \
  "$(printf '%s\n' $files | wc -w | tr -d ' ')" \
  "$total_tests" "$total_asserts" "$total_fails" "$total_skips" \
  "$(( $(date +%s) - start ))" "$narrowed_summary" "$skip_summary"

if [ "$total_fails" -ne 0 ]; then
  echo "FAILING FILES:$failed_files"
  exit 1
fi
echo "OK"
exit 0
