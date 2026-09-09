#!/usr/bin/env bash
# Deterministic read-trace benchmark, not an LLM or billing benchmark.
# Host token counters exist, but this trace does not invoke a provider or collect them.
# See drain-cache-run.py and docs/drain-prompt-caching.md for live measurements.
# Run with SIFT_TEST_KEEP=1 to retain its temporary transcripts.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"
DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"
READ="$DRAIN/read-context.sh"
root="$TMPROOT/project"
mkdir -p "$root"
make_tree "$root" ACME
export SIFT_ROOT="$root"

# The same 32 single-ticket sittings run through four retained worker contexts.
# The old read policy reloads three instruction units each sitting; the new
# policy reads each unit on that worker context's first assignment only.
mkdir -p "$TMPROOT/instructions"
printf '# Project instructions\nUse the project verification command and keep one commit per ticket.\n' > "$TMPROOT/instructions/AGENTS.md"
printf '# Knowledge entry\nShared ticket state is in the original checkout; workers use isolated worktrees.\n' > "$TMPROOT/instructions/ENTRY.md"

# Extract the current canonical section once for identical instruction bytes on
# both sides. That isolates read-frequency savings from unrelated prose edits.
page=1
: > "$TMPROOT/instructions/contract.md"
while :; do
  "$READ" "$REPO_ROOT/src/skills/sift-drain/references/ticket-agent-prompt.md" '## Template' "$page" > "$TMPROOT/page"
  sed '1d' "$TMPROOT/page" >> "$TMPROOT/instructions/contract.md"
  case "$(head -n 1 "$TMPROOT/page")" in *'next: none') break ;; esac
  page=$((page + 1))
done

n=1
while [ "$n" -le 32 ]; do
  id=$(printf 'ACME-%04d' "$n")
  ticket "$root" open backlog/bug "$id" item "Ticket $n" body=bug > /dev/null
  n=$((n + 1))
done
for name in before after before-bodies after-bodies before-instructions after-instructions previous; do
  : > "$TMPROOT/$name"
done
before_bodies=0; after_bodies=0; before_instructions=0; after_instructions=0

# Append every reader page exactly as it would be returned to the caller.
read_pages() {
  local file="$1" target="$2" page=1
  while :; do
    "$READ" "$file" --all "$page" > "$TMPROOT/page"
    cat "$TMPROOT/page" >> "$target"
    case "$(head -n 1 "$TMPROOT/page")" in *'next: none') break ;; esac
    page=$((page + 1))
  done
}

n=1
while [ "$n" -le 32 ]; do
  "$DRAIN/wave-status.sh" > "$TMPROOT/status"
  cat "$TMPROOT/status" >> "$TMPROOT/before"
  cat "$TMPROOT/status" >> "$TMPROOT/after"

  find "$root/.ai/sift/open" -name 'ACME-*.md' | LC_ALL=C sort > "$TMPROOT/open"
  while IFS= read -r file; do
    cat "$file" >> "$TMPROOT/before-bodies"
    cat "$file" >> "$TMPROOT/before"
    before_bodies=$((before_bodies + 1))
  done < "$TMPROOT/open"

  "$DRAIN/ticket-snapshot.sh" > "$TMPROOT/current"
  "$DRAIN/ticket-snapshot.sh" changes "$TMPROOT/previous" "$TMPROOT/current" > "$TMPROOT/changes"
  read_pages "$TMPROOT/changes" "$TMPROOT/after"
  while IFS="$(printf '\t')" read -r event id _old_path new_path; do
    case "$event:$new_path" in
      added:*/open/*|changed:*/open/*|moved+changed:*/open/*)
        cat "$new_path" >> "$TMPROOT/after-bodies"
        read_pages "$new_path" "$TMPROOT/after"
        after_bodies=$((after_bodies + 1)) ;;
    esac
  done < "$TMPROOT/changes"
  cp "$TMPROOT/current" "$TMPROOT/previous"
  "$DRAIN/ticket-snapshot.sh" > "$TMPROOT/current"
  "$DRAIN/ticket-snapshot.sh" changes "$TMPROOT/previous" "$TMPROOT/current" > "$TMPROOT/recheck"
  [ ! -s "$TMPROOT/recheck" ] || { echo 'fixture changed during intake' >&2; exit 1; }

  context=$(( (n - 1) % 4 + 1 ))
  mkdir -p "$TMPROOT/worker-$context"
  mkdir -p "$TMPROOT/worktree-$n"
  cp "$TMPROOT/instructions/"*.md "$TMPROOT/worktree-$n/"
  for file in "$TMPROOT/worktree-$n/"*.md; do
    cat "$file" >> "$TMPROOT/before-instructions"
    cat "$file" >> "$TMPROOT/before"
    before_instructions=$((before_instructions + 1))
    fingerprint=$(cksum < "$file")
    # Repository-relative identity survives the new absolute worktree path.
    known="$TMPROOT/worker-$context/$(basename "$file").cksum"
    if [ ! -f "$known" ] || [ "$(cat "$known")" != "$fingerprint" ]; then
      cat "$file" >> "$TMPROOT/after-instructions"
      read_pages "$file" "$TMPROOT/after"
      after_instructions=$((after_instructions + 1))
      printf '%s\n' "$fingerprint" > "$known"
    fi
  done

  # Archive one completed ticket using the real shipped operation.
  id=$(printf 'ACME-%04d' "$n")
  bash "$REPO_ROOT/src/operations/sift.sh" archive "$id" 'done' 'Fixture implementation verified' > "$TMPROOT/archive.log"
  n=$((n + 1))
done

bytes() { wc -c < "$1" | tr -d '[:space:]'; }
unique_instructions=$(find "$TMPROOT" -name '*.cksum' | wc -l | tr -d '[:space:]')
printf 'dispatches=32\nworker_contexts=4\n'
printf 'before_ticket_bodies=%s\nafter_ticket_bodies=%s\n' "$before_bodies" "$after_bodies"
printf 'before_ticket_body_bytes=%s\nafter_ticket_body_bytes=%s\n' "$(bytes "$TMPROOT/before-bodies")" "$(bytes "$TMPROOT/after-bodies")"
printf 'before_instruction_reads=%s\nafter_instruction_reads=%s\n' "$before_instructions" "$after_instructions"
printf 'before_repeated_instruction_reads=%s\nafter_repeated_instruction_reads=%s\n' \
  "$((before_instructions - unique_instructions))" "$((after_instructions - unique_instructions))"
printf 'before_instruction_bytes=%s\nafter_instruction_bytes=%s\n' "$(bytes "$TMPROOT/before-instructions")" "$(bytes "$TMPROOT/after-instructions")"
printf 'before_returned_bytes=%s\nafter_returned_bytes=%s\n' "$(bytes "$TMPROOT/before")" "$(bytes "$TMPROOT/after")"
printf 'before_input_tokens=unavailable\nafter_input_tokens=unavailable\n'
printf 'before_cached_tokens=unavailable\nafter_cached_tokens=unavailable\n'
printf 'before_output_tokens=unavailable\nafter_output_tokens=unavailable\n'
printf 'measurement=deterministic read trace; no model invoked\n'
if [ "${SIFT_TEST_KEEP:-0}" = 1 ]; then printf 'logs=%s\n' "$TMPROOT"; fi
