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

# struck_row <dir> <n> <id> <title> — a finished row in the shape rule 9 asks
# for: the ID and the title both struck, the resolution status appended.
struck_row() {
  printf '| %s | ~~%s~~ | ~~%s~~ — done |  |\n' "$2" "$3" "$4" >> "$1/.ai/sift/ROADMAP.md"
}

# roadmap_wave <dir> <n> — open another "## Wave <n>" section with its header.
roadmap_wave() {
  {
    printf '\n## Wave %s\n\n' "$2"
    printf '| # | Ticket | Title | Needs |\n'
    printf '|---|---|---|---|\n'
  } >> "$1/.ai/sift/ROADMAP.md"
}

# stub_ticket <dir> <bucket> <milestone/category> <filename> — content-free file,
# for recipes that only read the name (ID allocation).
stub_ticket() {
  local path="$1/.ai/sift/$2/$3"
  mkdir -p "$path"
  : > "$path/$4"
}

# fm_line <default-line> [caller-line…] — print the caller's line for this key
# when it supplied one, else the default. Keeps a fixture to one line per key:
# `ticket … 'type: feature'` has to yield a feature ticket, not a file carrying
# both `type: bug` and `type: feature`, or a recipe that greps for one type
# matches a fixture that claims to be the other.
fm_line() {
  local def="$1" key="${1%%:*}" line
  shift
  for line in "$@"; do
    case "$line" in "$key":*) printf '%s\n' "$line"; return ;; esac
  done
  printf '%s\n' "$def"
}

# ticket <dir> <bucket> <milestone/category> <id> <slug> <title> [extra-fm-lines]
# A complete, convention-shaped ticket file. An extra line naming one of the
# required keys replaces that key's default; any other extra line is appended
# verbatim before the closing fence.
ticket() {
  local dir="$1" bucket="$2" sub="$3" id="$4" slug="$5" title="$6"; shift 6
  local milestone="${sub%%/*}" cat="${sub##*/}"
  local d="$dir/.ai/sift/$bucket/$sub"
  mkdir -p "$d"
  {
    echo '---'
    fm_line "id: $id" "$@"
    fm_line "title: $title" "$@"
    fm_line 'status: open' "$@"
    fm_line 'type: bug' "$@"
    fm_line "milestone: $milestone" "$@"
    fm_line 'priority: p2' "$@"
    fm_line 'effort: m' "$@"
    fm_line 'created: 2026-08-01' "$@"
    fm_line 'updated: 2026-08-01' "$@"
    for line in "$@"; do
      case "$line" in
        id:*|title:*|status:*|type:*|milestone:*|priority:*|effort:*|created:*|updated:*) ;;
        *) echo "$line" ;;
      esac
    done
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
