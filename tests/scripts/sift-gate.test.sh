#!/usr/bin/env bash
# sift-gate.sh — root resolution and tree-state reporting (SFT-0008).
#
# The gate is the first thing every sift card runs, and it is the only component
# that decides WHERE the tree is. Two properties are worth more than the rest:
#
#   - Tier precedence over proximity. An existing tree beats a nearer .git, which
#     beats a nearer AGENTS.md. If proximity could ever win, a subdirectory $PWD
#     on a first run would materialise a SECOND tree with its own 0001 — an ID
#     collision the convention declares impossible and no migration can unpick.
#   - It never writes. Every case below re-checksums the tree afterwards, because
#     a gate that repairs what it inspects is a gate no card can trust to report.
#
# Every invocation is sandboxed: either SIFT_ROOT points into TMPROOT, or $PWD
# does. The first case proves the sandbox holds by asserting no marker exists
# above TMPROOT — otherwise the upward walk could reach the real repository.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

GATE="$REPO_ROOT/src/skills/sift-init/scripts/sift-gate.sh"

# gate_at <workdir> [env assignments…] — run the gate with $PWD inside TMPROOT.
gate_at() {
  local dir="$1"; shift
  run_cmd "$dir" env "$@" "$GATE"
}

# out_line <key> — the value of one key=value line from the last run's stdout.
out_line() {
  printf '%s\n' "$R_OUT" | awk -F= -v k="$1" '$1 == k { sub("^" k "=", ""); print; exit }'
}

# --- The sandbox itself ------------------------------------------------------

test_case "no sift marker exists above the temporary tree"
# Every tier assertion below reads "the nearest hit is the one I planted". That
# only holds while TMPROOT has no marker above it — and if one did exist, the
# walk could resolve to the real repository this suite is testing.
assert_eq "" "$(markers_above "$TMPROOT" .ai/sift .git AGENTS.md CLAUDE.md)" \
  "the upward walk from TMPROOT cannot reach a real project"

# --- Tier precedence ---------------------------------------------------------

test_case "an existing tree outranks a nearer .git"
root="$(newdir)"
make_tree "$root" ACME
mkdir -p "$root/pkg/api/src"
mkdir "$root/pkg/.git"
gate_at "$root/pkg/api/src"
assert_eq 0 "$R_STATUS" "exit 0: the initialised tree is READY"
assert_eq "$root" "$(out_line root)" "resolved to the tree, not to the nearer .git"
assert_eq "A" "$(out_line tier)" "tier A"
assert_eq ".ai/sift" "$(out_line marker)" "and names the marker that won"

test_case ".git outranks a nearer AGENTS.md"
root="$(newdir)"
mkdir "$root/.git"
mkdir -p "$root/pkg"
printf '# pkg\n' > "$root/pkg/AGENTS.md"
gate_at "$root/pkg"
assert_eq 3 "$R_STATUS" "exit 3: a root is known, the tree is not there yet"
assert_eq "$root" "$(out_line root)" "the repository root, not the instructed subpackage"
assert_eq "B" "$(out_line tier)" "tier B"
assert_eq "high" "$(out_line confidence)" "a .git root is worth initialising without asking"

test_case "a .git FILE is a root too"
# Worktrees and submodules write .git as a file holding a `gitdir:` pointer; a
# -d test misses every one of them.
root="$(newdir)"
printf 'gitdir: /elsewhere/.git/worktrees/wt\n' > "$root/.git"
gate_at "$root"
assert_eq 3 "$R_STATUS" "exit 3, exactly as for a .git directory"
assert_eq "B" "$(out_line tier)" "tier B"

test_case "an instructed project with no VCS is tier C and asks first"
for marker in AGENTS.md CLAUDE.md; do
  root="$(newdir)"
  printf '# instructions\n' > "$root/$marker"
  mkdir "$root/sub"
  gate_at "$root/sub"
  if [ "$R_STATUS" -eq 4 ] &&
     [ "$(out_line tier)" = "C" ] &&
     [ "$(out_line marker)" = "$marker" ] &&
     [ "$(out_line confidence)" = "low" ]
  then t_ok "$marker yields tier C, exit 4, low confidence — report and ask"
  else t_fail "$marker is tier C" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "AGENTS.md is preferred to CLAUDE.md at the same directory"
root="$(newdir)"
printf '# a\n' > "$root/AGENTS.md"
printf '# c\n' > "$root/CLAUDE.md"
gate_at "$root"
assert_eq "AGENTS.md" "$(out_line marker)" "one marker is reported, and it is the agent-neutral one"
assert_eq "CLAUDE.md" "$(out_line corroboration)" "the other is corroboration"

test_case "\$HOME is never a root"
# Nearly every agent user has ~/AGENTS.md or ~/.claude/CLAUDE.md, so an
# unbounded walk would land on the home directory and initialise it.
outer="$(newdir)"
printf '# project\n' > "$outer/AGENTS.md"
home="$outer/home"
mkdir -p "$home/sub"
mkdir "$home/.git"
gate_at "$home/sub" HOME="$home"
assert_eq 4 "$R_STATUS" "exit 4: it walked past \$HOME entirely"
assert_eq "$outer" "$(out_line root)" "even though \$HOME carried the higher-tier marker"
assert_eq "C" "$(out_line tier)" "so the answer came from the tier-C project above it"

test_case "no candidate root at all is a refusal, not a guess"
# The walk also inspects / and rejects it, which is why this ends in a refusal
# rather than resolving to the filesystem root.
root="$(newdir)"
gate_at "$root"
assert_eq 5 "$R_STATUS" "exit 5"
assert_contains "$R_OUT" 'state=UNRESOLVED' "reports the state on stdout"
assert_contains "$R_ERR" 'no sift root found at or above' "and says why on stderr"
assert_contains "$R_ERR" 'set SIFT_ROOT=' "with the escape hatch"
assert_no_dir "$root/.ai" "a refusal writes nothing"

# --- SIFT_ROOT override ------------------------------------------------------

test_case "SIFT_ROOT replaces the whole walk"
root="$(newdir)"
make_tree "$root" ACME
other="$(newdir)"
mkdir "$other/.git"
gate_at "$other" SIFT_ROOT="$root"
assert_eq 0 "$R_STATUS" "exit 0"
assert_eq "$root" "$(out_line root)" "the override wins over the \$PWD walk"
assert_eq "override" "$(out_line tier)" "and says the answer did not come from a tier"
assert_eq "SIFT_ROOT" "$(out_line marker)" "naming the variable as the marker"

test_case "an unreadable SIFT_ROOT is a usage error, not a refusal to find one"
root="$(newdir)"
gate_at "$root" SIFT_ROOT="$root/nowhere"
assert_eq 2 "$R_STATUS" "exit 2: the operator's own input is wrong"
assert_contains "$R_OUT" 'state=UNRESOLVED' "state is still reported"
assert_contains "$R_ERR" 'SIFT_ROOT is not a readable directory' "and named"

test_case "SIFT_ROOT at a directory with no tree reports UNINITIALIZED"
root="$(newdir)"
gate_at "$root" SIFT_ROOT="$root"
assert_eq 3 "$R_STATUS" "exit 3, the high-confidence branch"
assert_contains "$R_OUT" 'state=UNINITIALIZED' "an explicit root is as good as a .git one"
assert_no_dir "$root/.ai" "and still nothing is written"

# --- Tree state --------------------------------------------------------------

test_case "every required entry is required, one at a time"
for entry in README.md MILESTONES.md ROADMAP.md config/config.yaml open archive schemas; do
  root="$(newdir)"
  make_tree "$root" ACME
  rm -rf "${root:?}/.ai/sift/$entry"
  gate_at "$root" SIFT_ROOT="$root"
  if [ "$R_STATUS" -eq 6 ] &&
     [ "$(out_line state)" = "INCOMPLETE" ] &&
     [ "$(out_line missing)" = "$entry" ]
  then t_ok "a missing $entry is INCOMPLETE and named, exit 6"
  else t_fail "missing $entry" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "several missing entries are all listed"
root="$(newdir)"
make_tree "$root" ACME
rm -rf "$root/.ai/sift/schemas" "$root/.ai/sift/MILESTONES.md"
gate_at "$root" SIFT_ROOT="$root"
assert_eq 6 "$R_STATUS" "exit 6"
assert_eq "MILESTONES.md,schemas" "$(out_line missing)" \
  "comma-separated, in the order the gate checks them"

test_case "a config file with no prefix is INCOMPLETE, not READY"
# An empty prefix downstream builds the glob `-*.md`, which matches nothing and
# reads as an empty tree rather than as a broken one.
root="$(newdir)"
make_tree "$root" ACME
printf '# no prefix here\n' > "$root/.ai/sift/config/config.yaml"
gate_at "$root" SIFT_ROOT="$root"
assert_eq 6 "$R_STATUS" "exit 6"
assert_eq "config/config.yaml:prefix" "$(out_line missing)" "the key is named, not just the file"

test_case "a complete tree is READY and reads its prefix back"
root="$(newdir)"
make_tree "$root" ACME
gate_at "$root" SIFT_ROOT="$root"
assert_eq 0 "$R_STATUS" "exit 0"
assert_eq "READY" "$(out_line state)" "state=READY"
assert_eq "ACME" "$(out_line prefix)" "the configured prefix, not a default"

test_case "a quoted prefix is unwrapped"
for quoted in '"ACME"' "'ACME'"; do
  root="$(newdir)"
  make_tree "$root" ACME
  printf 'prefix: %s\n' "$quoted" > "$root/.ai/sift/config/config.yaml"
  gate_at "$root" SIFT_ROOT="$root"
  if [ "$R_STATUS" -eq 0 ] && [ "$(out_line prefix)" = "ACME" ]
  then t_ok "prefix: $quoted reads back as ACME"
  else t_fail "prefix: $quoted" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "the two config shapes that really reach disk read back the same prefix"
# SFT-0053: the gate is one of the four readers of config/config.yaml, and until
# now every fixture handed it a bare `prefix:` line — never the `#` comment header
# sift-init.sh installs above the key, nor README's trailing comment on the key's
# own line. The sed at sift-gate.sh:143 tolerates both by construction (it
# captures [A-Za-z0-9_] and discards the rest of the line, and `^prefix:` cannot
# match a comment), so this is coverage of an untested claim rather than a bug
# fix — but a change to that expression had nothing telling it otherwise.
for shape in commented inline bare; do
  root="$(newdir)"
  make_tree "$root" ACME
  config_yaml "$root" "$shape" ACME
  gate_at "$root" SIFT_ROOT="$root"
  if [ "$R_STATUS" -eq 0 ] && [ "$(out_line prefix)" = "ACME" ]
  then t_ok "the $shape config shape reads back as ACME"
  else t_fail "the $shape config shape" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "corroborating markers at the chosen root are reported"
root="$(newdir)"
make_tree "$root" ACME
mkdir "$root/.git"
printf '# a\n' > "$root/AGENTS.md"
gate_at "$root"
assert_eq "A" "$(out_line tier)" "the tree still wins the tier"
assert_eq ".git,AGENTS.md" "$(out_line corroboration)" "the other markers are listed, minus the winner"

test_case "a root with nothing beside the marker says so"
root="$(newdir)"
make_tree "$root" ACME
gate_at "$root"
assert_eq "none" "$(out_line corroboration)" "'none' rather than an empty value"

# --- The read-only contract --------------------------------------------------

test_case "the gate writes nothing, in any state"
root="$(newdir)"
make_tree "$root" ACME
before="$(tree_digest "$root")"
gate_at "$root" SIFT_ROOT="$root"
assert_eq 0 "$R_STATUS" "READY run"
assert_eq "$before" "$(tree_digest "$root")" "a READY tree is untouched"

rm "$root/.ai/sift/ROADMAP.md"
before="$(tree_digest "$root")"
gate_at "$root" SIFT_ROOT="$root"
assert_eq 6 "$R_STATUS" "INCOMPLETE run"
assert_eq "$before" "$(tree_digest "$root")" "an INCOMPLETE tree is not repaired by the gate"
assert_no_file "$root/.ai/sift/ROADMAP.md" "specifically, the missing entry stays missing"

root="$(newdir)"
mkdir "$root/.git"
gate_at "$root"
assert_eq 3 "$R_STATUS" "UNINITIALIZED run"
assert_no_dir "$root/.ai" "an uninitialised root is not initialised by being asked about"

summary
