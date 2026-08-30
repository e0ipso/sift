#!/usr/bin/env bash
# sift-gate: resolve the sift project root and report the tree's state. Reads only.
#
# Every sift skill runs this before it does anything else. It never writes, never
# creates, and never asks — it answers one question deterministically: "where is this
# repository's sift tree, and is it usable?"
#
# Determinism comes from three properties, not from stacking conditions:
#   - ONE upward walk from a canonicalised $PWD. No sideways scan, no downward scan,
#     no globbing. The same $PWD always yields the same answer.
#   - TIER PRECEDENCE over proximity. An existing tree beats a nearer .git, which
#     beats a nearer AGENTS.md. Nesting can never flip the result.
#   - REFUSE rather than guess. No candidate root means exit 5, not a plausible one.
#
# Tiers, checked at every level of the walk, nearest hit recorded per tier:
#   A  -d $dir/.ai/sift          already initialised — adopt
#   B  -e $dir/.git              repository root  (-e, not -d: worktrees and
#                                submodules write .git as a FILE holding a gitdir:
#                                pointer, and -d silently misses every one of them)
#   C  -f $dir/AGENTS.md         agent-instructed project with no VCS
#      -f $dir/CLAUDE.md
#
# Tier A is why the walk exists. It is the exit condition on every run after the
# first, pinning the root to one directory for the life of the repository, and on a
# first run it is the only thing standing between a subdirectory $PWD and a SECOND
# tree with its own 0001 — an ID collision the convention declares impossible and no
# find/sed migration can unpick.
#
# $HOME and / are never roots. Nearly every agent user has ~/.claude/CLAUDE.md or
# ~/AGENTS.md, so an unbounded tier-C walk would otherwise land on the home directory.
#
# Override the whole walk with SIFT_ROOT=/path (same variable sift-drain honours).
#
# Output: key=value lines on stdout.
#   state=READY|INCOMPLETE|UNINITIALIZED|UNRESOLVED
#   root=<absolute path>          (absent when UNRESOLVED)
#   tier=A|B|C                    (absent when UNRESOLVED)
#   marker=<what matched>         (absent when UNRESOLVED)
#   confidence=high|low           (UNINITIALIZED only)
#   corroboration=<other markers at root, comma-separated, or none>
#   missing=<entries, comma-separated>   (INCOMPLETE only)
#   prefix=<configured prefix>    (READY only)
#
# Exit codes:
#   0  READY          tree present and complete — proceed
#   3  UNINITIALIZED  tier B, high confidence — initialise without asking
#   4  UNINITIALIZED  tier C, low confidence  — report and ask before writing
#   5  UNRESOLVED     no candidate root — ask for an explicit path
#   6  INCOMPLETE     tree present but missing required entries — repair
#   2  usage/environment error
# tests/static/gate-handoff-contract.test.sh compares the exit 4 and 6 action comments
# above with the init skill and both consuming skills.

set -u

emit() { printf '%s\n' "$*"; }

# --- Resolve the root -------------------------------------------------------

hit_a=''; hit_b=''; hit_c=''; marker_c=''

if [ -n "${SIFT_ROOT:-}" ]; then
  root=$(cd "$SIFT_ROOT" 2>/dev/null && pwd -P) || {
    emit "state=UNRESOLVED"
    echo "error: SIFT_ROOT is not a readable directory: $SIFT_ROOT" >&2
    exit 2
  }
  tier='override'; marker='SIFT_ROOT'
else
  dir=$(pwd -P) || exit 2
  while :; do
    # $HOME and / are inspected but never eligible.
    if [ "$dir" != "/" ] && [ "$dir" != "${HOME:-/dev/null/nonexistent}" ]; then
      if [ -z "$hit_a" ] && [ -d "$dir/.ai/sift" ]; then hit_a=$dir; fi
      if [ -z "$hit_b" ] && [ -e "$dir/.git" ]; then hit_b=$dir; fi
      if [ -z "$hit_c" ]; then
        if [ -f "$dir/AGENTS.md" ]; then
          hit_c=$dir; marker_c='AGENTS.md'
        elif [ -f "$dir/CLAUDE.md" ]; then
          hit_c=$dir; marker_c='CLAUDE.md'
        fi
      fi
    fi
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && break
    dir=$parent
  done

  # Precedence is by TIER, not by distance: in a monorepo, packages/api/AGENTS.md
  # never outranks the repository's .git, and neither outranks an existing tree.
  if   [ -n "$hit_a" ]; then root=$hit_a; tier='A'; marker='.ai/sift'
  elif [ -n "$hit_b" ]; then root=$hit_b; tier='B'; marker='.git'
  elif [ -n "$hit_c" ]; then root=$hit_c; tier='C'; marker="$marker_c"
  else
    emit "state=UNRESOLVED"
    echo "error: no sift root found at or above $(pwd -P)" >&2
    echo "hint: run from inside the project, or set SIFT_ROOT=/path/to/project" >&2
    exit 5
  fi
fi

# --- Corroborating markers at the chosen root -------------------------------

corr=''
for m in .git AGENTS.md CLAUDE.md .ai/sift; do
  [ "$m" = "$marker" ] && continue
  if [ -e "$root/$m" ]; then
    if [ -z "$corr" ]; then corr="$m"; else corr="$corr,$m"; fi
  fi
done
[ -z "$corr" ] && corr='none'

emit "root=$root"
emit "tier=$tier"
emit "marker=$marker"
emit "corroboration=$corr"

# --- Report the tree's state ------------------------------------------------

sift="$root/.ai/sift"

if [ ! -d "$sift" ]; then
  emit "state=UNINITIALIZED"
  case "$tier" in
    C) emit "confidence=low";  exit 4 ;;
    *) emit "confidence=high"; exit 3 ;;
  esac
fi

# Required entries. Everything else (milestone folders, categories, tickets) is
# created on demand by the first ticket and its absence is not a defect.
missing=''
for entry in README.md MILESTONES.md ROADMAP.md config/config.yaml open archive schemas; do
  if [ ! -e "$sift/$entry" ]; then
    if [ -z "$missing" ]; then missing="$entry"; else missing="$missing,$entry"; fi
  fi
done

if [ -n "$missing" ]; then
  emit "state=INCOMPLETE"
  emit "missing=$missing"
  exit 6
fi

prefix=$(sed -n 's/^prefix:[[:space:]]*["'\'']\{0,1\}\([A-Za-z0-9_]\{1,\}\).*/\1/p' \
  "$sift/config/config.yaml" | head -n 1)
if [ -z "$prefix" ]; then
  emit "state=INCOMPLETE"
  emit "missing=config/config.yaml:prefix"
  exit 6
fi

emit "state=READY"
emit "prefix=$prefix"
exit 0
