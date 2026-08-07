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
newline="$(printf 'a\nb')"
for m in '../evil' 'a/../../../evil' 'foo/bar' '.' '..' 'Foo' '-lead' 'trail-' \
         'a--b' 'a b' '' "$newline" '/abs' 'a.b' '~' '*'; do
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

test_case "a traversing name writes nothing outside the root either"
root="$(newdir)"
init_milestone "$root" 'a/../../../evil'
assert_eq 2 "$R_STATUS" "exits 2"
assert_no_dir "$TMPROOT/evil" "nothing landed beside the project"
assert_no_dir "$root/../evil" "nor one level up from it"
assert_no_dir "$root/.ai" "nor inside it"

test_case "the default milestone is backlog"
root="$(newdir)"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'first milestone: backlog' "reports the default"
if [ -d "$root/.ai/sift/open/backlog" ]; then t_ok "open/backlog exists"
else t_fail "open/backlog exists" "$(find "$root/.ai" | head)"; fi

summary
