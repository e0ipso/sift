#!/usr/bin/env bash
# sift-init.sh --milestone (SFT-0001).
#
# The milestone becomes a path component under open/, so the WHOLE value is
# validated before the first mkdir. The regression this pins is a validator
# that only looked at the leading character: `a/../../../evil` passed it, and
# `mkdir -p` then resolved the tree outside the project.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

INIT="$REPO_ROOT/src/skills/sift-init/scripts/sift-init.sh"

init_milestone() {  # init_milestone <root> <milestone>
  run_cmd "$1" "$INIT" --root "$1" --prefix SFT --milestone "$2"
}

test_case "accepted milestone names build the tree"
for m in backlog v1-2 a 1 alpha-beta-gamma-9; do
  root="$(newdir)"
  init_milestone "$root" "$m"
  if [ "$R_STATUS" -eq 0 ] && [ -d "$root/.ai/sift/open/$m" ] &&
     grep -q "^## $m\$" "$root/.ai/sift/MILESTONES.md"
  then t_ok "'$m' is accepted and gets open/$m plus a MILESTONES.md section"
  else t_fail "'$m' is accepted" "status=$R_STATUS" "stderr=$R_ERR"; fi
done

test_case "rejected milestone names never reach a mkdir"
# The empty string and the embedded newline are passed as real argv values, so
# the case statement — not the shell that typed them — is what rejects them.
#
# One row per branch, not one per spelling (SFT-0075). The guard has five arms
# ('' | -* | *- | *--* | *[!a-z0-9-]*) and the first four take one row each. The
# character-class arm takes one row per distinct claim: '../evil' stands for
# every dot-or-slash spelling (foo/bar, /abs, ., .., a.b, a/../../../evil), 'Foo'
# is the collation claim constraint 1 of SFT-0075 keeps and the locale loop below
# re-drives, 'a b' is a space, "$newline" is a real argv newline no other row
# carries, and '*' is a glob metacharacter. The traversal claim is pinned by the
# dedicated case below and by the destructive control further down, not by
# counting spellings here.
newline="$(printf 'a\nb')"
for m in '../evil' 'Foo' '-lead' 'trail-' 'a--b' 'a b' '' "$newline" '*'; do
  root="$(newdir)"
  init_milestone "$root" "$m"
  label="$(printf '%s' "$m" | tr '\n' '~')"
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'milestone must be lowercase kebab-case'*) true ;; *) false ;; esac &&
     [ ! -e "$root/.ai" ]
  then t_ok "'${label:-<empty>}' exits 2 with a diagnostic and no .ai/ directory"
  else t_fail "'${label:-<empty>}' is rejected" "status=$R_STATUS" "stderr=$R_ERR" \
      "tree: $(find "$root" -maxdepth 3 | head -n 5)"; fi
done

test_case "an uppercase milestone is rejected under a UTF-8 locale with collated ranges"
# A locale switch alone proves nothing on bash 5.0+, where globasciiranges is
# enabled by default. Clear it explicitly to reproduce the matcher stock macOS
# bash uses. Foo is deliberate: under aAbBcC…zZ collation, A..Y fall inside
# [a-z], but Z sorts after z and would not discriminate the range from the
# explicit character list.
#
# Only Foo is repeated from the rejection matrix. The empty and hyphen-shape
# rows ('', -lead, trail-, a--b) are rejected before the character class; the
# remaining rows contain /, ., space, newline or *, all outside a collated
# a-z in every locale the suite drives.
: "${matrix_locales:?recipes.sh did not define matrix_locales}"
for loc in $matrix_locales; do
  locale_available "$loc" || continue

  root="$(newdir)"
  R_LOCALE="$loc" run_cmd "$root" bash +O globasciiranges "$INIT" \
    --root "$root" --prefix SFT --milestone Foo
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'milestone must be lowercase kebab-case'*) true ;; *) false ;; esac &&
     [ ! -e "$root/.ai" ]
  then t_ok "'Foo' rejected under LC_ALL=$loc with globasciiranges disabled"
  else t_fail "'Foo' was accepted under LC_ALL=$loc with globasciiranges disabled" \
    "status=$R_STATUS" "stderr=$R_ERR"; fi

  root="$(newdir)"
  R_LOCALE="$loc" run_cmd "$root" bash +O globasciiranges "$INIT" \
    --root "$root" --prefix SFT --milestone backlog
  if [ "$R_STATUS" -eq 0 ] && [ -d "$root/.ai/sift/open/backlog" ]
  then t_ok "'backlog' accepted under LC_ALL=$loc with globasciiranges disabled"
  else t_fail "'backlog' accepted under LC_ALL=$loc with globasciiranges disabled" \
    "status=$R_STATUS" "stderr=$R_ERR"; fi
done
# R_LOCALE is an input global read by run_cmd in tests/lib/harness.sh, so no
# reader for it exists in this file. The reset is load-bearing: without it every
# case below this loop would keep running under the last available UTF-8 locale.
# shellcheck disable=SC2034
R_LOCALE=C

test_case "a traversing name writes nothing outside the root either"
root="$(newdir)"
init_milestone "$root" 'a/../../../evil'
assert_eq 2 "$R_STATUS" "exits 2"
assert_no_dir "$TMPROOT/evil" "nothing landed beside the project"
assert_no_dir "$root/../evil" "nor one level up from it"
assert_no_dir "$root/.ai" "nor inside it"

# --- The destructive sequence, run for real (SFT-0008) -----------------------
#
# Every case above proves the refusal happens. None proves the refusal MATTERS:
# they assert that nothing landed at a path chosen by the test, which a guard
# that did nothing would also satisfy if the test simply miscounted the `..`.
# A throwaway tree is the disposable environment for settling that, so these two
# cases build a sandbox with a populated sift tree sitting exactly where the
# traversal points, run the escape for real to prove it reaches, and only then
# assert that the guarded run leaves every path and every byte of it alone.

# inventory <dir> — every path under <dir>, directories included. tree_digest
# reads files only, so a traversal that created nothing but an empty directory
# beside the project would slip straight past it.
inventory() { find "$1" | LC_ALL=C sort; }

# victim_sandbox — <sandbox>/victim holds a populated sift tree with a ticket in
# it; <sandbox>/repo is the uninitialised project whose init is about to be
# pointed at it. From <sandbox>/repo/.ai/sift/open, four levels up is <sandbox>.
victim_sandbox() {
  local s
  s="$(newdir)"
  mkdir -p "$s/victim/.ai/sift/open/backlog/bug" "$s/repo"
  printf -- '---\nid: VIC-0001\n---\n\n# Someone else'\''s work\n' \
    > "$s/victim/.ai/sift/open/backlog/bug/VIC-0001--precious.md"
  printf '# Roadmap\n\n## Wave 1\n' > "$s/victim/.ai/sift/ROADMAP.md"
  printf '%s\n' "$s"
}

ESCAPE='../../../../victim/.ai/sift/open/pwned'

test_case "the traversal a rejected milestone asks for really does escape"
# The positive control. `mkdir -p "$sift/open/$milestone"` is the line the
# initializer runs once the milestone is accepted; run it unguarded and the
# directory appears inside the neighbouring project. Without this, the case
# below could pass because the path was wrong rather than because a guard held.
s="$(victim_sandbox)"
mkdir -p "$s/repo/.ai/sift/open/$ESCAPE"
if [ -d "$s/victim/.ai/sift/open/pwned" ]
then t_ok "unguarded, the milestone resolves inside the tree next door"
else t_fail "unguarded, the milestone resolves inside the tree next door" \
  "$(inventory "$s" | head -n 20)"; fi

test_case "the guard holds where a real tree would have been damaged"
s="$(victim_sandbox)"
before_paths="$(inventory "$s")"
before_bytes="$(tree_digest "$s")"
init_milestone "$s/repo" "$ESCAPE"
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" 'milestone must be lowercase kebab-case' "with the diagnostic"
assert_eq "$before_paths" "$(inventory "$s")" \
  "not one path was created anywhere in the sandbox, empty directories included"
assert_eq "$before_bytes" "$(tree_digest "$s")" \
  "and the ticket in the tree next door is byte-identical"

test_case "the default milestone is backlog"
root="$(newdir)"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'first milestone: backlog' "reports the default"
if [ -d "$root/.ai/sift/open/backlog" ]; then t_ok "open/backlog exists"
else t_fail "open/backlog exists" "$(find "$root/.ai" | head)"; fi

summary
