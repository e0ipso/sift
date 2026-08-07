#!/usr/bin/env bash
# fixtures.sh — build throwaway sift trees for the integration tests.
#
# Trees are built by hand rather than by sift-init so a cookbook test can pin
# one recipe without dragging the initializer into its failure modes; the
# scripts/ and e2e/ suites drive sift-init through its real interface.

# make_tree <dir> [prefix] — a minimal but gate-complete tree at <dir>/.ai/sift.
make_tree() {
  local dir="$1" prefix="${2:-SFT}"
  mkdir -p "$dir/.ai/sift/open" "$dir/.ai/sift/archive" \
           "$dir/.ai/sift/schemas" "$dir/.ai/sift/config"
  printf 'prefix: %s\n' "$prefix" > "$dir/.ai/sift/config/config.yaml"
  printf '# sift\n' > "$dir/.ai/sift/README.md"
  printf '# Milestones\n\n## backlog\n' > "$dir/.ai/sift/MILESTONES.md"
  roadmap_new "$dir"
}

# roadmap_new <dir> — an empty Wave 1 table, the shape sift-init writes.
roadmap_new() {
  cat > "$1/.ai/sift/ROADMAP.md" <<'EOF'
# Roadmap

## Wave 1

| # | Ticket | Title | Needs |
|---|---|---|---|
EOF
}

# roadmap_row <dir> <n> <id> <title> [needs]
roadmap_row() {
  printf '| %s | %s | %s | %s |\n' "$2" "$3" "$4" "${5:--}" >> "$1/.ai/sift/ROADMAP.md"
}

# stub_ticket <dir> <bucket> <milestone/category> <filename> — content-free file,
# for recipes that only read the name (ID allocation).
stub_ticket() {
  local path="$1/.ai/sift/$2/$3"
  mkdir -p "$path"
  : > "$path/$4"
}

# ticket <dir> <bucket> <milestone/category> <id> <slug> <title> [extra-fm-lines]
# A complete, convention-shaped ticket file. Extra front-matter lines are
# appended verbatim before the closing fence.
ticket() {
  local dir="$1" bucket="$2" sub="$3" id="$4" slug="$5" title="$6"; shift 6
  local milestone="${sub%%/*}" cat="${sub##*/}"
  local d="$dir/.ai/sift/$bucket/$sub"
  mkdir -p "$d"
  {
    echo '---'
    echo "id: $id"
    echo "title: $title"
    echo 'status: open'
    echo 'type: bug'
    echo "milestone: $milestone"
    echo 'priority: p2'
    echo 'effort: m'
    echo 'created: 2026-08-01'
    echo 'updated: 2026-08-01'
    for line in "$@"; do echo "$line"; done
    echo '---'
    echo
    echo "# $title"
    echo
    echo '## Problem'
    echo 'Placeholder body for the fixture.'
  } > "$d/$id--$slug.md"
  printf '%s\n' "$d/$id--$slug.md"
  : "$cat"
}

# fm <file> <key> — read one front-matter value (test-side reimplementation, so
# a bug in the product's own parser cannot mask itself).
fm() {
  awk -v k="$2" '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && index($0, k ":") == 1 {
      sub("^" k ":[[:space:]]*", "")
      print
      exit
    }
  ' "$1"
}
