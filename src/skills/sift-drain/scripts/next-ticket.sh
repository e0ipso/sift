#!/usr/bin/env bash
# next-ticket.sh — print the next sift ticket to dispatch.
#
# Walks .ai/sift/ROADMAP.md in wave order and prints the first ticket row that
# is not ~~struck~~ (i.e. not archived) and not `status: blocked`, together with
# its file path and the front-matter the orchestrator needs to size the work.
#
# The lookup reports its own state under `result: found|none`, never under
# `status:` — that key belongs to the echoed front-matter, and one key meaning
# two things in one report is how a first-match parser reads "found" as a ticket
# status. Every key printed here is unique within an invocation; keep it so.
#
# Usage:
#   scripts/next-ticket.sh                 # next dispatchable ticket
#   scripts/next-ticket.sh --include-blocked
#   scripts/next-ticket.sh --group         # …plus its whole dispatch group
#   scripts/next-ticket.sh --include-blocked --   # -- ends the options
#
# `--` means one thing across the card: the option list ends here and everything
# behind it is positional. This script has no positional to take, so the marker
# is accepted and anything following it is a usage error. `--group` is a flag,
# so it belongs in front of the marker like every other option.
#
# --group adds `group_size:`, `group_tickets:` and a `group_files:` block naming
# the tickets that may be dispatched together with the lead: those carrying the
# same `cluster` front-matter value, bounded by GROUP_MAX_TICKETS and
# GROUP_MAX_WEIGHT below. The lead is unchanged, and so is every other line of
# the report — without the flag this script prints exactly what it always did.
#
# Exit codes: 0 found | 1 nothing left to dispatch | 2 setup/usage/consistency error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: next-ticket.sh [--include-blocked] [--group]" >&2
  echo "note: -- ends the options; this script takes no argument behind it" >&2
  exit 2
}

# The bounds on one dispatch group. Four tickets is what a reviewer can hold in
# one diff; eight effort points is one `xl` — so a group is at most one xl-sized
# piece of work however it is spelled, and four tickets never add up to more.
GROUP_MAX_TICKETS=4
GROUP_MAX_WEIGHT=8

INCLUDE_BLOCKED=0
GROUP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --include-blocked) INCLUDE_BLOCKED=1 ;;
    --group) GROUP=1 ;;
    --)
      shift
      break
      ;;
    *) usage ;;
  esac
  shift
done

# Behind the marker every argument is positional, and there is no positional to
# be: `next-ticket.sh -- --include-blocked` named a ticket, not the flag, and
# answering with the blocked ones included would be the plausible wrong answer.
[ $# -eq 0 ] || usage

ROWS="$(roadmap_rows)"
[ -n "$ROWS" ] || { echo "error: no ticket rows parsed from $ROADMAP" >&2; exit 2; }

CHOSEN_WAVE=""
CHOSEN_ORDER=""
CHOSEN_ID=""
CHOSEN_FILE=""
SKIPPED=""

while IFS=$'\t' read -r wave order id struck _title; do
  [ "$struck" = "1" ] && continue
  file="$(ticket_file "$id")"
  if [ -z "$file" ]; then
    echo "error: roadmap row $order lists $id but no ticket file exists" >&2
    echo "hint: run scripts/roadmap-check.sh" >&2
    exit 2
  fi
  case "$file" in
    */archive/*)
      # Archived but not struck: a rule-9 violation, not a dispatchable ticket.
      SKIPPED="$SKIPPED$id (archived but roadmap row not struck)"$'\n'
      continue
      ;;
  esac
  if [ "$INCLUDE_BLOCKED" = "0" ] && [ "$(fm_value "$file" status)" = "blocked" ]; then
    SKIPPED="$SKIPPED$id (status: blocked)"$'\n'
    continue
  fi
  CHOSEN_WAVE="$wave"; CHOSEN_ORDER="$order"; CHOSEN_ID="$id"; CHOSEN_FILE="$file"
  break
done <<< "$ROWS"

if [ -z "$CHOSEN_ID" ]; then
  echo "result: none"
  echo "note: every roadmap row is struck or skipped — the roadmap is drained"
  [ -n "$SKIPPED" ] && printf 'skipped:\n%s' "$SKIPPED"
  exit 1
fi

REMAINING="$(printf '%s\n' "$ROWS" | awk -F'\t' -v w="$CHOSEN_WAVE" '$1 == w && $4 == 0 { printf "%s ", $3 }')"
REMAINING_COUNT="$(printf '%s\n' "$ROWS" | awk -F'\t' -v w="$CHOSEN_WAVE" '$1 == w && $4 == 0' | wc -l | tr -d ' ')"

# --- The dispatch group ------------------------------------------------------
# Everything below runs only under --group, which is what keeps the default
# report byte-identical: the lead was already chosen above, by the loop that has
# always chosen it, so priority and row order still decide what runs next.

# read_cluster <id> <file> — the ticket's cluster into CLUSTER, empty when it
# has none. A value that is not a well-formed label is treated as absent and
# named under skipped:, never as a hard error: `cluster` is advisory, so a typo
# has to cost the batching and nothing else. It cannot return the value through
# a command substitution, because the skipped: line it appends is a side effect
# a subshell would throw away.
CLUSTER=''
read_cluster() {
  local raw
  CLUSTER="$(ticket_cluster "$2")"
  [ -n "$CLUSTER" ] && return 0
  raw="$(fm_value "$2" cluster)"
  [ -n "$raw" ] || return 0
  SKIPPED="$SKIPPED$1 (cluster: $raw is not kebab-case, so it groups alone)"$'\n'
}

# A group of one, until a cluster says otherwise: the lead alone is always a
# legal answer, so `--group` on a ticket that names no cluster reports the same
# three keys rather than omitting them.
GROUP_IDS="$CHOSEN_ID"
GROUP_FILES="$CHOSEN_FILE"
GROUP_SIZE=1
GROUP_WEIGHT=0
LEAD_CLUSTER=''

if [ "$GROUP" = "1" ]; then
  read_cluster "$CHOSEN_ID" "$CHOSEN_FILE"
  LEAD_CLUSTER="$CLUSTER"
  GROUP_WEIGHT="$(effort_weight "$(fm_value "$CHOSEN_FILE" effort)")"
fi

if [ -n "$LEAD_CLUSTER" ]; then
  # A second pass over the same rows, starting behind the lead. Membership is
  # exactly dispatchability plus a matching cluster, so a group can never hold a
  # ticket the script would refuse to hand out on its own.
  #
  # `gap` records that an unstruck row went by that is not a member — unfinished
  # work sitting between the lead and whatever comes next. Once one has been
  # seen, the group stops at the wave boundary rather than crossing it: reaching
  # into wave n+1 while wave n still has open rows would start the next wave
  # early, which is the one thing the wave gate exists to prevent.
  #
  # Nothing here is reported beyond the malformed cluster above. Every row this
  # pass steps over is a row a later dispatch reaches as its own lead, and the
  # loop above names it then; the cluster is the exception because no other pass
  # ever reads it.
  seen_lead=0
  gap=0
  while IFS=$'\t' read -r wave _order id struck _title; do
    if [ "$seen_lead" = "0" ]; then
      [ "$id" = "$CHOSEN_ID" ] && seen_lead=1
      continue
    fi
    [ "$struck" = "1" ] && continue
    [ "$wave" != "$CHOSEN_WAVE" ] && [ "$gap" = "1" ] && break
    member=0
    file="$(ticket_file "$id")"
    if [ -n "$file" ]; then
      case "$file" in
        */archive/*) ;;   # terminal work, and a rule-9 violation besides
        *)
          if [ "$INCLUDE_BLOCKED" = "1" ] || [ "$(fm_value "$file" status)" != "blocked" ]; then
            read_cluster "$id" "$file"
            [ "$CLUSTER" = "$LEAD_CLUSTER" ] && member=1
          fi
          ;;
      esac
    fi
    if [ "$member" = "0" ]; then
      gap=1
      continue
    fi
    # Both bounds are tested before the ticket is added, and the first breach
    # BREAKS. Continuing past it would skip a large ticket in favour of a
    # smaller one further down the roadmap, which reorders the roadmap silently.
    weight="$(effort_weight "$(fm_value "$file" effort)")"
    [ $((GROUP_SIZE + 1)) -gt "$GROUP_MAX_TICKETS" ] && break
    [ $((GROUP_WEIGHT + weight)) -gt "$GROUP_MAX_WEIGHT" ] && break
    GROUP_SIZE=$((GROUP_SIZE + 1))
    GROUP_WEIGHT=$((GROUP_WEIGHT + weight))
    GROUP_IDS="$GROUP_IDS $id"
    GROUP_FILES="$GROUP_FILES"$'\n'"$file"
  done <<< "$ROWS"
fi

echo "result: found"
echo "wave: $CHOSEN_WAVE"
echo "order: $CHOSEN_ORDER"
echo "ticket: $CHOSEN_ID"
echo "file: $CHOSEN_FILE"
for key in id title status type milestone priority effort depends_on labels; do
  printf '%s: %s\n' "$key" "$(fm_value "$CHOSEN_FILE" "$key")"
done
echo "remaining_in_wave: $REMAINING_COUNT"
echo "remaining_ids: ${REMAINING% }"
if [ "$GROUP" = "1" ]; then
  # Three keys, none of them colliding with one already printed above: `id` is
  # the lead's own, echoed from its front matter, so nothing here is a group_id
  # (SFT-0018 — one key means one thing per invocation). group_files is a block
  # rather than one line because a path may hold a blank, which a
  # space-separated list could not survive.
  echo "group_size: $GROUP_SIZE"
  echo "group_tickets: $GROUP_IDS"
  printf 'group_files:\n%s\n' "$GROUP_FILES"
fi
[ -n "$SKIPPED" ] && printf 'skipped:\n%s' "$SKIPPED"
exit 0
