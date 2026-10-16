#!/usr/bin/env bash
# sift-init.sh --suggest-worktree-links, --worktree-link and --worktree-command.
#
# Detection must stay read-only and must never offer the tracker, or anything
# that contains it, as a symlink: a linked .ai/sift would make every worker
# write the coordinator's live tracker through a path it believes is its own.
# Publication goes through the same create-if-absent path as every other file,
# so an operator's edited hook survives a repair run byte for byte. The last
# case runs a published hook through prepare-worktree.sh, the only caller.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

INIT="$REPO_ROOT/src/skills/sift-init/scripts/sift-init.sh"
PREPARE="$REPO_ROOT/src/skills/sift-drain/scripts/prepare-worktree.sh"
HOOK_REL=".ai/sift/config/worktree-setup"

# Keep git from walking out of the sandbox into whatever holds TMPROOT.
suggest() { run_cmd "$1" env GIT_CEILING_DIRECTORIES="$TMPROOT" "$INIT" --suggest-worktree-links --root "$1"; }

git_repo() {  # git_repo — a fresh repository on main with one empty commit
  local d
  d="$(newdir)"
  git -C "$d" init -q
  git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
  git -C "$d" branch -M main
  printf '%s\n' "$d"
}

has_line() {  # has_line <text> <line> — exact whole-line match
  printf '%s\n' "$1" | grep -qxF -- "$2"
}

# hook_lines <report> — report entries naming the hook. TMPROOT's own name
# contains "worktree-setup", so a bare substring would match the header line.
hook_lines() {
  printf '%s\n' "$1" | grep -E '^  [a-z]+ +\.ai/sift/config/worktree-setup' || [ $? -eq 1 ]
}

test_case "detection lists ignored local paths and nothing of the tracker"
d="$(git_repo)"
printf '.env\n.env.local\n.ai/sift/\nnode_modules/\n' > "$d/.gitignore"
printf 'tracked\n' > "$d/README.md"
git -C "$d" add .gitignore README.md
git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm tracked
printf 'SECRET=1\n' > "$d/.env"
printf 'LOCAL=1\n' > "$d/.env.local"
mkdir -p "$d/.ai/sift/open" "$d/node_modules/pkg"
printf 'live\n' > "$d/.ai/sift/open/x.md"
printf 'dep\n' > "$d/node_modules/pkg/index.js"
printf 'scratch\n' > "$d/untracked-not-ignored.txt"
before="$(tree_digest "$d")"
suggest "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_ERR" "prints no diagnostics"
if has_line "$R_OUT" .env && has_line "$R_OUT" .env.local
then t_ok "lists .env and .env.local"
else t_fail "lists .env and .env.local" "out=$R_OUT"; fi
if has_line "$R_OUT" node_modules
then t_ok "an ignored directory is listed once, without its trailing /"
else t_fail "an ignored directory is listed without its trailing /" "out=$R_OUT"; fi
assert_eq "" "$(printf '%s\n' "$R_OUT" | grep '/$' || [ $? -eq 1 ])" "no line ends in /"
assert_eq "" "$(printf '%s\n' "$R_OUT" | grep -e '^\.ai/sift$' -e '^\.ai/sift/' -e '^\.ai$' || [ $? -eq 1 ])" \
  "neither .ai/sift, a path under it, nor the .ai that contains it is offered"
assert_not_contains "$R_OUT" README.md "a tracked file is not offered"
assert_not_contains "$R_OUT" untracked-not-ignored.txt "an untracked file git does not ignore is not offered"
assert_eq "$(printf '%s\n' "$R_OUT" | LC_ALL=C sort -u)" "$R_OUT" "output is sorted and unique"
assert_eq "$before" "$(tree_digest "$d")" "not one byte of the fixture changed"
assert_no_dir "$d/.ai/sift/config" "no tracker scaffolding was created"

test_case "detection drops names git can only print quoted"
d="$(git_repo)"
printf 'odd*\n.env\n' > "$d/.gitignore"
printf 'x\n' > "$d/odd$(printf '\t')name"
printf 'x\n' > "$d/.env"
suggest "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$(printf '%s\n' "$R_OUT" | grep '^"' || [ $? -eq 1 ])" "no C-quoted line reaches the output"
if has_line "$R_OUT" .env; then t_ok "plain names still come through"
else t_fail "plain names still come through" "out=$R_OUT"; fi

test_case "detection outside a git work tree prints nothing"
d="$(newdir)"
printf 'x\n' > "$d/.env"
before="$(tree_digest "$d")"
suggest "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"
assert_eq "$before" "$(tree_digest "$d")" "writes nothing"
assert_no_dir "$d/.ai" "creates no .ai directory"

test_case "the help header documents the new mode and options"
run_cmd "$TMPROOT" "$INIT" -h
assert_eq 0 "$R_STATUS" "-h exits 0"
for opt in --suggest-worktree-links '--worktree-link PATH' '--worktree-command CMD'; do
  assert_contains "$R_OUT" "$opt" "-h documents $opt"
done

# One published hook shared by the publication and integration cases.
pub="$(git_repo)"
printf '.env\n.ai/\nsetup.log\ndir with space/\n' > "$pub/.git/info/exclude"
printf 'SECRET=fixture\n' > "$pub/.env"
mkdir -p "$pub/dir with space"
printf 'odd\n' > "$pub/dir with space/f&g.txt"
hook="$pub/$HOOK_REL"

test_case "hook options publish one executable bash hook"
run_cmd "$pub" "$INIT" --root "$pub" --prefix ACME \
  --worktree-link .env --worktree-link 'dir with space/f&g.txt' --worktree-link missing.env \
  --worktree-command "printf '%s\\n' first >> setup.log" \
  --worktree-command "printf '%s\\n' \"\$SIFT_ROOT\" >> setup.log"
assert_eq 0 "$R_STATUS" "exits 0"
if [ -f "$hook" ] && [ -x "$hook" ]; then t_ok "the hook is an executable regular file"
else t_fail "the hook is an executable regular file" "$(ls -l "$hook" 2>&1)"; fi
assert_contains "$R_OUT" "created  $HOOK_REL" "the report names the hook as created"
assert_eq 1 "$(hook_lines "$R_OUT" | grep -c .)" "the report has exactly one hook line"
assert_contains "$R_OUT" "gate: READY" "the tree is still READY"
if bash -n "$hook" 2>/dev/null; then t_ok "the hook parses under bash -n"
else t_fail "the hook parses under bash -n" "$(bash -n "$hook" 2>&1)"; fi
assert_eq '#!/usr/bin/env bash' "$(head -n 1 "$hook")" "the hook is a bash script"
assert_eq "" "$(grep -o 'SIFT_[A-Z_]*' "$hook" | grep -vx SIFT_ROOT || [ $? -eq 1 ])" \
  "SIFT_ROOT is the only SIFT_ variable the generated steps read"
assert_not_contains "$(cat "$hook")" "$pub" "no absolute path from the init run is baked in"
assert_contains "$(cat "$hook")" "# Link .env from the original checkout" "the link step names its origin"
assert_contains "$(cat "$hook")" "printf '%s\\n' first >> setup.log" "a command is written verbatim"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$hook" >/dev/null 2>&1; then t_ok "shellcheck accepts the hook"
  else t_fail "shellcheck accepts the hook" "$(shellcheck "$hook" 2>&1 | head -n 20)"; fi
else
  skip "shellcheck on the generated hook" "shellcheck not installed"
fi
cp "$hook" "$TMPROOT/hook.orig"

test_case "a repeat run keeps the existing hook byte for byte"
run_cmd "$pub" "$INIT" --root "$pub" --prefix ACME --worktree-command 'echo changed'
assert_eq 0 "$R_STATUS" "exits 0"
assert_same "$TMPROOT/hook.orig" "$hook" "the hook is unchanged"
assert_contains "$R_OUT" "kept     $HOOK_REL" "the report names the hook as kept"
assert_not_contains "$R_OUT" "created  $HOOK_REL" "and never as created"

test_case "the hook mode honours the operator's umask"
d="$(newdir)"
run_cmd "$d" sh -c 'umask 077; exec "$@"' sh "$INIT" --root "$d" --prefix ACME --worktree-command true
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "-rwx------" "$(ls -l "$d/$HOOK_REL" | cut -c1-10)" "umask 077 yields 0700"

test_case "without hook options no hook is written or reported"
d="$(newdir)"
run_cmd "$d" "$INIT" --root "$d" --prefix ACME
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$d/$HOOK_REL" "no hook file"
assert_eq "" "$(hook_lines "$R_OUT")" "no hook line in the report"

test_case "invalid links and commands exit 2 before any write"
nl='
'
check_rejected() {  # check_rejected <option> <value>
  local d label
  d="$(newdir)"
  run_cmd "$d" "$INIT" --root "$d" --prefix ACME "$1" "$2"
  label="$(printf '%s' "$1 [$2]" | tr '\n' '~')"
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *error:*"$1"*) true ;; *) false ;; esac &&
     [ ! -e "$d/.ai" ]
  then t_ok "$label exits 2, names the option, and creates no .ai/"
  else t_fail "$label is rejected" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
# Absolute, `..`, `.` and empty components, the tracker, the .ai that holds
# it, an embedded newline, and the empty value.
for v in /abs ../x .. a/../b a/.. .ai/sift .ai/sift/x .ai/sift/ .ai ./.ai/sift \
         . ./x a/./b a//b a/ "x${nl}y" ''; do
  check_rejected --worktree-link "$v"
done
# Empty, an embedded newline, and text bash cannot parse as a step.
for v in '' "x${nl}y" "echo 'unterminated" 'if true; then'; do
  check_rejected --worktree-command "$v"
done
d="$(newdir)"
run_cmd "$d" "$INIT" --root "$d" --prefix ACME --worktree-link
assert_eq 2 "$R_STATUS" "a missing --worktree-link value exits 2"

test_case "prepare-worktree.sh runs the published hook in the new worktree"
wt="$TMPROOT/wt"
run_cmd "$pub" "$PREPARE" main w/one "$wt"
assert_eq 0 "$R_STATUS" "prepare-worktree.sh exits 0"
assert_contains "$R_OUT" "worktree=$wt" "and reports the worktree"
root="$(cd "$pub" && pwd -P)"
if [ -L "$wt/.env" ] && [ "$(readlink "$wt/.env")" = "$root/.env" ]
then t_ok ".env is a symlink to the original checkout's .env"
else t_fail ".env is a symlink to the original" "$(ls -l "$wt/.env" 2>&1)"; fi
assert_eq "SECRET=fixture" "$(cat "$wt/.env")" "and reads through to its content"
if [ -L "$wt/dir with space/f&g.txt" ] && [ "$(cat "$wt/dir with space/f&g.txt")" = odd ]
then t_ok "a nested path with a space and & is linked under its created parent"
else t_fail "a nested path with a space and & is linked" "$(ls -lR "$wt" 2>&1 | head -n 20)"; fi
assert_no_file "$wt/missing.env" "a link whose source is absent is skipped"
assert_eq "$(printf 'first\n%s' "$root")" "$(cat "$wt/setup.log" 2>&1)" \
  "commands run verbatim, in order, in the worktree, with SIFT_ROOT set"
assert_no_dir "$wt/.ai" "the tracker is not brought into the worktree"

test_case "a rerun skips existing targets silently"
other="$(newdir)"
printf 'mine\n' > "$other/.env"
run_cmd "$other" env SIFT_ROOT="$root" "$hook"
assert_eq 0 "$R_STATUS" "the hook exits 0"
assert_eq "" "$R_ERR" "with nothing on stderr"
if [ -f "$other/.env" ] && [ ! -L "$other/.env" ] && [ "$(cat "$other/.env")" = mine ]
then t_ok "an existing regular file is left alone"
else t_fail "an existing regular file is left alone" "$(ls -l "$other/.env" 2>&1)"; fi
before="$(readlink "$wt/.env")"
run_cmd "$wt" env SIFT_ROOT="$root" "$hook"
assert_eq 0 "$R_STATUS" "a second run in a prepared worktree exits 0"
assert_eq "$before" "$(readlink "$wt/.env")" "and keeps the existing link"

summary
