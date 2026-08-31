#!/usr/bin/env bash
# fixtures.sh — build throwaway sift trees for the integration tests.
#
# Trees are built by hand rather than by sift-init so a cookbook test can pin
# one recipe without dragging the initializer into its failure modes; the
# scripts/ and e2e/ suites drive sift-init through its real interface. The
# agreement between this hand-built tree and a real init is pinned in
# tests/scripts/sift-init-tree.test.sh.

# Permission-fault fixtures keep their own restore stack because a skipped
# denial must be as clean as a denial the platform enforced.  Arrays keep paths
# containing spaces intact; every test file sourcing this library runs in bash.
SIFT_DENIED_PATHS=()
SIFT_DENIED_MODES=()
SIFT_DENIED_BACKUPS=()

# fixture_mode <path> — the ordinary rwx mode as three octal digits.  Test
# fixtures do not carry set-id or sticky bits, so POSIX ls is enough and avoids
# depending on either incompatible spelling of stat(1).
fixture_mode() {
  LC_ALL=C ls -ld "$1" | awk '
    {
      p = substr($1, 2, 9)
      for (i = 0; i < 3; i++) {
        n = 0
        if (substr(p, i * 3 + 1, 1) == "r") n += 4
        if (substr(p, i * 3 + 2, 1) == "w") n += 2
        if (substr(p, i * 3 + 3, 1) == "x") n += 1
        printf "%d", n
      }
      printf "\n"
    }
  '
}

# restore_write <path> — restore the mode and, for a file probe, its bytes;
# then remove this path from the restore stack.
restore_write() {
  local path="$1" i mode backup
  for ((i=${#SIFT_DENIED_PATHS[@]} - 1; i >= 0; i--)); do
    [ "${SIFT_DENIED_PATHS[$i]}" = "$path" ] || continue
    mode="${SIFT_DENIED_MODES[$i]}"
    backup="${SIFT_DENIED_BACKUPS[$i]}"
    chmod "$mode" "$path" || return 2
    if [ -n "$backup" ]; then
      cp "$backup" "$path" || return 2
      rm -f "$backup"
    fi
    unset 'SIFT_DENIED_PATHS[i]' 'SIFT_DENIED_MODES[i]' 'SIFT_DENIED_BACKUPS[i]'
    return 0
  done
  return 2
}

# deny_write <path> — remove write permission, record how to restore it, and
# prove the current uid is actually denied.  Directory probes create a child;
# file probes append one byte and keep a backup so even a root/non-enforcing
# platform returns the file byte-identical.  A non-zero result means the caller
# must emit a named skip: chmod alone is not evidence that writes are denied.
deny_write() {
  local path="$1" mode backup='' probe index
  mode="$(fixture_mode "$path")" || return 2
  if [ -d "$path" ]; then
    chmod 500 "$path" || return 2
  elif [ -f "$path" ]; then
    backup="$(mktemp "$TMPROOT/denied-file.XXXXXX")" || return 2
    cp "$path" "$backup" || { rm -f "$backup"; return 2; }
    chmod 444 "$path" || { rm -f "$backup"; return 2; }
  else
    return 2
  fi

  index="${#SIFT_DENIED_PATHS[@]}"
  SIFT_DENIED_PATHS[$index]="$path"
  SIFT_DENIED_MODES[$index]="$mode"
  SIFT_DENIED_BACKUPS[$index]="$backup"

  if [ -d "$path" ]; then
    probe="$path/.sift-write-probe.$$.$index"
    if ( : > "$probe" ) 2>/dev/null; then
      rm -f "$probe"
      restore_write "$path"
      return 1
    fi
  elif ( printf x >> "$path" ) 2>/dev/null; then
    restore_write "$path"
    return 1
  fi
  return 0
}

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

# config_yaml <dir> <shape> [prefix] — rewrite the tree's config file in one of
# the shapes that really reach a reader (SFT-0053).
#
# `make_tree` writes a bare `prefix:` line and keeps doing so, because changing
# the default would rewrite the input of every existing case in one commit and
# hide which cases actually pin a shape. The other two are the ones the project
# documents and installs, and until this helper existed no reader was ever handed
# either of them:
#
#   commented   the `#` header sift-init.sh writes above the key, which is what
#               every initialized repository actually gets
#   inline      README's example: the value followed by a trailing `#` comment on
#               the same line
#   bare        make_tree's default, so a case can put it back
#
# What is pinned is the shape — comment lines above the key, a comment after the
# value — not the wording of either comment.
config_yaml() {
  local dir="$1" shape="$2" prefix="${3:-SFT}" f
  f="$dir/.ai/sift/config/config.yaml"
  mkdir -p "$dir/.ai/sift/config"
  case "$shape" in
    commented)
      { printf '# Sift per-repository configuration.\n'
        printf '#\n'
        printf '# The prefix is immutable for the life of the repository: it is baked into every\n'
        printf '# ticket ID, every filename, and every inline PREFIX-XXXX cross-reference.\n'
        printf 'prefix: %s\n' "$prefix"
      } > "$f" ;;
    inline)
      printf 'prefix: %s      # uppercase; stable for the life of the repository\n' \
        "$prefix" > "$f" ;;
    bare)
      printf 'prefix: %s\n' "$prefix" > "$f" ;;
    *)
      echo "config_yaml: unknown shape: $shape" >&2; return 2 ;;
  esac
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

# ticket_body <shape> — the body `ticket` writes under the repeated title.
#
# The headings are spelled exactly as README's templates spell them, because a
# heading is parsed API: sift-drain reads `## Direction`, and the cookbook's two
# backfill recipes grep for `## Expected behaviour` and `## Direction` verbatim.
# A fixture that spells one differently is a fixture that agrees with nothing, so
# the spelling is not left to trust: tests/cookbook/validation.test.sh asserts
# each shape below against the template extracted from README.md (SFT-0052), and
# a heading that drifts here fails there.
#
# `default` is byte-identical to the body every fixture ticket carried before
# SFT-0053. It has to be: this library is sourced by every group, so a changed
# default silently rewrites the input of assertions nobody was touching.
ticket_body() {
  case "$1" in
    default)
      echo '## Problem'
      echo 'Placeholder body for the fixture.'
      ;;
    canonical)
      echo '## Problem'
      echo 'Placeholder problem for the fixture.'
      echo
      echo '## Evidence'
      echo '- tests/lib/fixtures.sh:1'
      echo
      echo '## Direction'
      echo 'Placeholder direction for the fixture.'
      echo
      echo '## Acceptance criteria'
      echo '- [ ] Placeholder criterion for the fixture.'
      ;;
    bug)
      echo '## Problem'
      echo 'Placeholder problem for the fixture.'
      echo
      echo '## Expected behaviour'
      echo 'Placeholder expectation for the fixture.'
      echo
      echo '## Steps to reproduce'
      echo '1. Placeholder step for the fixture.'
      echo
      echo '## Evidence'
      echo '- tests/lib/fixtures.sh:1'
      echo
      echo '## Direction'
      echo 'Placeholder direction for the fixture.'
      echo
      echo '## Acceptance criteria'
      echo '- [ ] Placeholder criterion for the fixture.'
      ;;
    feature)
      echo '## Problem'
      echo 'Placeholder motivation for the fixture.'
      echo
      echo '## Evidence'
      echo '- tests/lib/fixtures.sh:1'
      echo
      echo '## Direction'
      echo 'Placeholder proposal for the fixture.'
      echo
      echo '## Alternatives considered'
      echo 'Placeholder alternative for the fixture.'
      echo
      echo '## Acceptance criteria'
      echo '- [ ] Placeholder criterion for the fixture.'
      ;;
    adversarial)
      # One shape for both front-matter rewrites (SFT-0053). `archive` and
      # `move-milestone` each used to build a near-identical body of their own,
      # differing only in which keys the prose quoted. This quotes every key
      # either rewrite touches, which is strictly stronger than both and safe for
      # both: neither recipe rewrites a key the other one does, so every line
      # below has to survive byte for byte whichever recipe runs — which is what
      # both suites already assert.
      #
      # Two horizontal rules, one plain and one carrying a trailing space. Both
      # are legal markdown and both match the fence pattern the recipes walk, so
      # a rewrite scoped only by that pattern would re-open the front-matter
      # block here (SFT-0016, widened by SFT-0026). No line quotes a value a
      # recipe under test writes, so a `grep -c` for the written line still
      # counts exactly one.
      echo '## Direction'
      echo 'status: open is what the body claims.'
      echo 'updated: never, says the body.'
      echo 'resolution: also quoted here.'
      echo 'milestone: caching is what the body claims.'
      echo
      echo '---'
      echo
      echo 'status: and again, after a plain horizontal rule.'
      echo 'milestone: and again, after a plain horizontal rule.'
      echo
      echo '--- '
      echo
      echo 'updated: and again, after a spaced horizontal rule.'
      echo 'resolution: and again, after a spaced horizontal rule.'
      ;;
    *)
      echo "ticket_body: unknown shape: $1" >&2; return 2 ;;
  esac
}

# ticket <dir> <bucket> <milestone/category> <id> <slug> <title> [extra…]
#
# A complete, convention-shaped ticket file. Extra arguments come in two kinds
# that cannot be confused, because one carries a colon and the other an equals
# sign, and both REPLACE rather than append:
#
#   `<key>: <value>`  front matter. A line naming one of the required keys
#                     replaces that key's default; any other line is written
#                     verbatim inside the fence, which is how an optional key
#                     like `source:` gets set. `wave:` is required in `open/`,
#                     where it defaults to 1, and optional in `archive/`, where
#                     it is written only when the caller passes it.
#   `body=<shape>`    the body, one of the shapes ticket_body names above.
#                     Never derived from `type:`: the bug-backfill recipe's whole
#                     subject is a `type: bug` ticket with no
#                     `## Expected behaviour`, so coupling the two would make its
#                     positive case unbuildable.
ticket() {
  local dir="$1" bucket="$2" sub="$3" id="$4" slug="$5" title="$6"; shift 6
  local milestone="${sub%%/*}" cat="${sub##*/}" body='default' arg
  local d="$dir/.ai/sift/$bucket/$sub"
  for arg in "$@"; do
    case "$arg" in body=*) body="${arg#body=}" ;; esac
  done
  # Validated before the redirection below, where a non-zero return would be
  # swallowed by the group and the caller would get a half-written ticket.
  ticket_body "$body" > /dev/null || return 2
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
    # The wave, keyed off the bucket rather than off `status:`, because the
    # bucket is what the caller always passes and what the tree is read by. An
    # open ticket carries a wave; an archived one keeps whichever wave it was
    # drafted with and is never handed one it never had, so a fixture for a
    # ticket resolved before the key existed stays buildable.
    case "$bucket" in
      open) fm_line 'wave: 1' "$@" ;;
      *) for arg in "$@"; do
           case "$arg" in wave:*) printf '%s\n' "$arg" ;; esac
         done ;;
    esac
    fm_line 'created: 2026-08-01' "$@"
    fm_line 'updated: 2026-08-01' "$@"
    for line in "$@"; do
      case "$line" in
        id:*|title:*|status:*|type:*|milestone:*|priority:*|effort:*|wave:*|created:*|updated:*) ;;
        # The shape selector, excluded here rather than passed through: this loop
        # writes any unrecognised argument verbatim inside the fence, so a
        # selector that fell through would land in the ticket as a bogus key.
        body=*) ;;
        *) echo "$line" ;;
      esac
    done
    echo '---'
    echo
    echo "# $title"
    echo
    ticket_body "$body"
  } > "$d/$id--$slug.md"
  printf '%s\n' "$d/$id--$slug.md"
  : "$cat"
}

# space_the_fence <file> — put one trailing space on both front-matter markers.
# YAML permits it after a document marker, so the result is still a valid ticket.
space_the_fence() {
  awk 'n < 2 && /^---[[:space:]]*$/ { n++; print "--- "; next } { print }' "$1" \
    > "$1.spaced" && mv "$1.spaced" "$1"
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
