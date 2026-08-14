#!/usr/bin/env bash
# recipes.sh — run the cookbook's own commands, extracted from README.md.
#
# The recipes in README.md are the reference implementation, so the tests must
# execute the documented text rather than a paraphrase of it: a recipe that
# drifts from its tests is exactly the failure this suite exists to catch.
#
# Each extractor pulls a fenced block out of README.md by its anchor line. A
# reworded anchor makes the extractor return nothing and the test fail loudly,
# which is the intended coupling.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
README="$REPO_ROOT/README.md"

# readme_block <anchor-substring> [nth-block] — print one fenced block verbatim.
readme_block() {
  awk -v anchor="$1" -v want="${2:-1}" '
    !found { if (index($0, anchor)) found = 1; next }
    /^```/ {
      if (!inblock) { inblock = 1; blk++; next }
      inblock = 0
      if (blk == want) exit
      next
    }
    inblock && blk == want { print }
  ' "$README"
}

recipe_prefix_setup()  { readme_block '**Set the prefix once per shell.**'; }
recipe_allocate()      { readme_block '**Allocate the next ID**'; }
recipe_roadmap_check() { readme_block '**Roadmap consistency check**'; }
recipe_frontmatter()   { readme_block '**Validate front-matter across the tree**'; }
# The conditional half of the same rule: `resolution` is required only once a
# status is terminal, which the nine-key loop above has no way to express.
recipe_resolution()    { readme_block '**Find tickets archived without a'; }

# Query recipes. All read-only, all driven by $PREFIX (and $MILESTONE where the
# recipe names one), so they run verbatim — no parameter swap is needed.
recipe_milestone_setup() { readme_block 'Recipes that name one milestone read'; }
recipe_list_open()       { readme_block '**List every open ticket:**'; }
recipe_triage()          { readme_block '**Triage view'; }
recipe_count_milestone() { readme_block '**Count open tickets per milestone:**'; }
recipe_find_ticket()     { readme_block '**Find a ticket wherever it lives:**'; }
recipe_fulltext()        { readme_block '**Full-text search'; }
recipe_dependents()      { readme_block '**Who depends on'; }
recipe_next()            { readme_block '**Pick the next thing to work on**'; }

# Front-matter parsing: the three `labels:` recipes share one awk program.
recipe_labels_list()  { readme_block '**List every label in use**'; }
recipe_labels_count() { readme_block '**Count tickets per label:**'; }

# The label filter opens with a literal `LABEL=caching` from the worked example.
# Swap it for a parameter expansion so a case can ask for a label no ticket
# carries; the caller asserts the swap landed, so a README rewording cannot
# silently degrade the test back to the example value.
recipe_labels_filter() {
  readme_block '**List tickets carrying one label**' \
    | sed 's|^LABEL=caching$|LABEL=${LABEL?}|'
}

# Audit recipes: the two section-backfill lists and the folder/front-matter check.
recipe_bug_sections()     { readme_block '**Find bug tickets missing'; }
recipe_feature_missing()  { readme_block '**Find feature tickets whose Direction'; }
recipe_folder_agreement() { readme_block '**Sanity-check folder/front-matter agreement:**'; }
recipe_xmllint()          { readme_block '**Machine-check a draft'; }

# The milestone move opens with a `DEST=<target-milestone>` placeholder, which is
# a redirection rather than an assignment when run as written, and the worked
# example's `ID=$PREFIX-0042`. Swap both so a case can drive them; callers assert
# both swaps landed.
recipe_move_milestone() {
  readme_block '**Move a ticket to another milestone**' | sed \
    -e 's|^DEST=<target-milestone>.*$|DEST=${DEST:?}|' \
    -e 's|^ID=\$PREFIX-0042$|ID=${ID:?}|'
}

# The archive recipe opens with three literal assignments (the worked example's
# ID, status and resolution). Swap them for parameter expansions so a case can
# drive the recipe from the environment; every caller asserts the swap landed,
# so a README rewording cannot silently degrade the test to the example values.
recipe_archive() {
  readme_block '**Archive a finished ticket**' | sed \
    -e 's|^ID=\$PREFIX-0042$|ID=${ID:?}|' \
    -e 's|^STATUS=done[[:space:]].*$|STATUS=${STATUS:?}|' \
    -e "s|^RESOLUTION='Fixed in commit abc1234'.*$|RESOLUTION=\${RESOLUTION?}|"
}

# --- The normative blocks that are not `sh` recipes (SFT-0052) ---------------
#
# The cookbook's recipes are executed by extraction, so they cannot drift from
# the prose documenting them. Every other normative fenced block in README.md is
# just as normative — the ✱-marked keys ARE the front-matter API and the `type`
# alternation IS the category folder set — and each one was hand-copied into a
# test or checked by nothing at all. One extractor per block below, on the same
# terms as the recipes: a reworded anchor returns nothing, and every caller
# asserts non-empty output before it compares, so an anchor that stopped matching
# fails on the extraction rather than passing a comparison of two empty sets.
#
# Extraction is from the repository-root README.md only. The shipped mirror
# src/skills/sift-init/assets/README.md is held byte-identical to it by
# tests/scripts/sync-assets.test.sh, so extracting there as well would pin a copy
# of a copy.
#
# Each anchor is a named constant rather than a literal inside the call, because
# the negative control below has to reword THE anchor its extractor reads. A
# control holding a second copy of the string would keep passing after the two
# spellings drifted apart — it would reword a line the extractor no longer looks
# for, watch it return nothing, and call that the coupling working.
ANCHOR_LAYOUT='## Directory layout'
ANCHOR_FRONTMATTER='Every ticket starts with YAML front-matter.'
ANCHOR_BODY_CANONICAL='Every body is built from four canonical sections'
ANCHOR_BODY_BUG='— a bug ticket that does not say what'
ANCHOR_BODY_FEATURE='`Problem` carries the motivation'
ANCHOR_RUNLOG='Six columns, and a literal'
ANCHOR_REFRESH='followed by the two commands below with the paths already resolved'

readme_layout()              { readme_block "$ANCHOR_LAYOUT"; }
readme_frontmatter_example() { readme_block "$ANCHOR_FRONTMATTER"; }
readme_body_canonical()      { readme_block "$ANCHOR_BODY_CANONICAL"; }
readme_body_bug()            { readme_block "$ANCHOR_BODY_BUG"; }
readme_body_feature()        { readme_block "$ANCHOR_BODY_FEATURE"; }
readme_runlog_schema()       { readme_block "$ANCHOR_RUNLOG"; }
readme_refresh()             { readme_block "$ANCHOR_REFRESH"; }

# readme_reworded <dir> <anchor> — a copy of README.md at <dir>/README.md with
# the first line carrying <anchor> replaced by prose that no longer carries it.
# Prints the path to the copy.
#
# The negative control every extractor above was documented to have and none of
# them ran (SFT-0052, criterion 9). "A reworded anchor makes the extractor return
# nothing and the test fail loudly" is a claim about a path no case had taken:
# each caller asserts its extraction is non-empty, but all of them assert it
# against a README whose anchors all match. Rewording one in place is out of the
# question — README.md is the file the no-writes digest in
# static/suite-contract.test.sh watches most closely — so the control runs against
# a copy, with $README repointed at it for the length of one case and restored
# after. The restoration is asserted rather than assumed: every caller re-runs the
# extractor against the real README as its last assertion.
#
# Returns 1 and prints nothing when no line carried the anchor, so a caller can
# never read "the anchor was already gone" as "the extractor coped without it".
readme_reworded() {
  local dest="$1/README.md"
  awk -v anchor="$2" '
    !hit && index($0, anchor) { print "**An anchor line reworded by a negative control.**"; hit = 1; next }
    { print }
    END { exit(hit ? 0 : 1) }
  ' "$README" > "$dest" || return 1
  printf '%s\n' "$dest"
}

# --- Turning an extracted block into the set it states ------------------------

# set_diff <listA> <listB> — the non-empty lines of A that are absent from B.
#
# Line-based, not word-based: a body heading is several words. Set equality is
# asserted by calling this twice rather than by comparing two sorted blobs, so a
# failure names the member that moved *and* the direction it moved in — a one-way
# comparison never sees a withdrawal.
set_diff() {
  printf '%s\n' "$1" | awk -v b="$2" '
    BEGIN { n = split(b, w, "\n"); for (i = 1; i <= n; i++) if (w[i] != "") have[w[i]] = 1 }
    $0 != "" && !($0 in have) { print }
  '
}

# alternation_after <marker> — read lines on stdin and print the `a | b | c`
# alternation that follows <marker> on each, one member per line.
#
# The marker is located with index() and consumed with substr/length, never as a
# bracket expression or a range: both markers this is used with (`←`, `✱`) are
# multi-byte, and a byte-oriented awk reads a bracket expression holding one as
# the set of its individual bytes. index()/substr()/length() all count in the
# same units as each other on any one awk, so the pair agrees across the C,
# C.utf8 and en_US.utf8 legs the suite replays.
alternation_after() {
  awk -v marker="$1" '
    { p = index($0, marker) }
    p == 0 { next }
    {
      n = split(substr($0, p + length(marker)), part, "|")
      for (i = 1; i <= n; i++) {
        v = part[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (v != "") print v
      }
    }
  '
}

# The closed `type` set, from each of the three places it is written out: the
# <category> comment in the layout tree, the `type:` comment in the front-matter
# example, and the enumeration in the XSD.
readme_layout_types()      { readme_layout | grep '<category>' | alternation_after '←'; }
readme_frontmatter_types() { readme_frontmatter_example | grep '^type:' | alternation_after '✱'; }

# xsd_enum <simpleType-name> — the enumeration members of one XSD simple type.
# The schemas are drafting scaffolding rather than storage, but this particular
# enumeration is a third copy of a README set, so it is read out rather than
# restated.
xsd_enum() {
  awk -v want="$1" '
    index($0, "<xs:simpleType name=\"" want "\">") { inside = 1; next }
    inside && index($0, "</xs:simpleType>") { exit }
    inside && match($0, /value="[^"]*"/) { print substr($0, RSTART + 7, RLENGTH - 8) }
  ' "$REPO_ROOT/schemas/sift-common.xsd"
}

# readme_required_keys — the ✱-marked keys of the front-matter example, which is
# where "required" is defined. `resolution:` carries no ✱: it is required only
# once a ticket is archived, which is a rule the example cannot express.
readme_required_keys() {
  readme_frontmatter_example | awk '
    index($0, "✱") == 0 { next }
    { key = $1; sub(/:$/, "", key); print key }
  '
}

# recipe_required_keys — the keys the front-matter validation recipe loops over.
# A `for` list rather than a grep, so a key withdrawn from the example shows up
# here as an extra as well as showing up there as a missing one.
recipe_required_keys() {
  recipe_frontmatter | awk '
    index($0, "for k in ") != 1 { next }
    { for (i = 4; i <= NF; i++) {
        if ($i == "do") break
        key = $i; sub(/;$/, "", key)
        if (key != "") print key
      }
      exit }
  '
}

# block_headings [annotation] — the `## ` headings one body-template block names,
# in template order, with the `←` annotation stripped off. Given an argument,
# only the headings whose annotation opens with that word (`required`,
# `optional`), which is how the templates mark the ones a type really needs.
block_headings() {
  awk -v want="${1:-}" '
    substr($0, 1, 3) != "## " { next }
    {
      p = index($0, "←")
      head = (p ? substr($0, 1, p - 1) : $0)
      note = (p ? substr($0, p + length("←")) : "")
      gsub(/[[:space:]]+$/, "", head)
      gsub(/^[[:space:]]+/, "", note)
      if (want == "" || index(note, want) == 1) print head
    }
  '
}

# recipe_grepped_heading <recipe-text> — the `## ` heading a section-backfill
# recipe tests each ticket for, unquoted and unanchored.
recipe_grepped_heading() {
  printf '%s\n' "$1" | awk '
    { p = index($0, "grep -q ") }
    p == 0 { next }
    {
      rest = substr($0, p + length("grep -q "))
      q = substr(rest, 1, 1)
      rest = substr(rest, 2)
      e = index(rest, q)
      if (e) rest = substr(rest, 1, e - 1)
      sub(/^\^/, "", rest)
      print rest
      exit
    }
  '
}

# readme_runlog_header — the run log's header block, down to and including the
# table separator: everything the writer lays down once, before the first row.
readme_runlog_header() {
  readme_runlog_schema | awk '{ print } substr($0, 1, 2) == "|-" { exit }'
}

# readme_runlog_columns — the documented column names, in order.
readme_runlog_columns() {
  readme_runlog_schema | awk -F'|' '
    substr($0, 1, 1) != "|" { next }
    substr($0, 1, 2) == "|-" { next }
    { for (i = 2; i < NF; i++) {
        c = $i; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c); print c
      }
      exit }
  '
}

# readme_refresh_resolved <card-dir> <tree-root> — the refresh recipe's `cp`
# lines with `$CARD` and the tree root substituted and the shell quoting removed,
# which is the form the initializer prints them in.
#
# Substitution is a concatenation, never a sed or gsub replacement text: both
# values are absolute paths and a replacement is re-scanned for `&` and
# backreferences. `.ai/sift` is rooted first, so a card directory that happened
# to contain that string could not be rewritten a second time.
readme_refresh_resolved() {
  readme_refresh | awk -v card="$1" -v root="$2" '
    function subst(s, from, to,   p, out) {
      out = ""
      while ((p = index(s, from)) > 0) {
        out = out substr(s, 1, p - 1) to
        s = substr(s, p + length(from))
      }
      return out s
    }
    {
      line = $0
      gsub(/"/, "", line)
      line = subst(line, ".ai/sift", root "/.ai/sift")
      line = subst(line, "$CARD", card)
      print line
    }
  '
}

# layout_entries — the paths the directory-layout block draws, one per line,
# relative to `.ai/sift/` and with a trailing `/` on every directory.
#
# Depth is counted by stripping one indent unit at a time and comparing each
# candidate against the same literal, rather than by counting characters: `│` and
# the `──` connectors are multi-byte, so length() answers in bytes on one awk and
# in characters on another. substr() against a literal is right under both.
layout_entries() {
  readme_layout | awk '
    {
      line = $0
      if (line ~ /^[[:space:]]*$/) next
      depth = 0
      while (1) {
        if (substr(line, 1, length("│   ")) == "│   ") {
          line = substr(line, length("│   ") + 1); depth++; continue
        }
        if (substr(line, 1, 4) == "    ") { line = substr(line, 5); depth++; continue }
        break
      }
      c = substr(line, 1, length("├── "))
      if (c != "├── " && c != "└── ") next          # the `.ai/sift/` root line
      line = substr(line, length("├── ") + 1)
      split(line, f, /[[:space:]]+/)
      stack[depth] = f[1]
      path = ""
      for (i = 0; i <= depth; i++) path = path stack[i]
      print path
    }
  '
}

# --- Running an extracted recipe --------------------------------------------
#
# The environment a case runs in when it pins nothing — the one every plain
# cookbook case therefore already used. Declared once and read twice: by
# `recipe_runner` below as its fallbacks, and by `baseline_leg` further down as
# the combination the sweeps must not re-run (SFT-0078). Writing `bash`/`C` a
# second time inside the sweeps would let the two drift, and the drift would be
# silent in both directions — a sweep excluding a leg the runner no longer
# defaults to drops real coverage, and one that misses the new default goes back
# to re-running the plain case.
RECIPE_DEFAULT_SHELL=bash
RECIPE_DEFAULT_LOCALE=C
RECIPE_DEFAULT_AWK=''   # empty: no shim, so `awk` is whatever PATH resolves
#
# run_recipe <workdir> <script-text> [VAR=VAL ...]
#
# Sets R_STATUS, R_OUT, R_ERR. Honours three knobs so one case can be replayed
# across the portability matrix:
#   R_SHELL  bash | dash          (default $RECIPE_DEFAULT_SHELL)
#   R_AWK    absolute awk path    (default: whatever PATH resolves)
#   R_LOCALE LC_ALL value         (default $RECIPE_DEFAULT_LOCALE)
#
# The block is run under `set -e`: the cookbook's guards are `… || { echo …;
# false; }` one-liners, and their documented "stops with the tree untouched"
# contract only holds when a failing command ends the run.
run_recipe() { recipe_runner 'set -e' "$@"; }

# run_recipe_plain <workdir> <script-text> [VAR=VAL ...]
#
# The same runner with the `set -e` line left off — the shell an operator pastes
# into, where a guard only *reports*. Use it to pin what survives a failed guard
# (SFT-0034: no guard may end the shell it was pasted into); everything that
# asserts a run stopped keeps `run_recipe`, whose `set -e` is what makes the
# "stops with the tree untouched" contract testable at all.
run_recipe_plain() { recipe_runner '' "$@"; }

# recipe_runner <options-line|''> <workdir> <script-text> [VAR=VAL ...]
#
# R_STATUS/R_OUT/R_ERR are the return channel, read by the test files that source
# this library. shellcheck reads one file at a time and so cannot see those reads;
# exporting them would be a lie, since the readers share this shell rather than
# being child processes.
#
# Empty script text is refused here rather than run (SFT-0081). Every caller
# hands this function the output of an extractor whose whole contract is that a
# reworded — or deleted — fenced block yields nothing, and running nothing exits
# 0 having printed nothing: exactly what the cookbook's negative cases assert, so
# a recipe deleted from README.md left ten of them green. The refusal is a
# counted `t_fail` naming the caller's case and the line that called, not a
# silent `return`, for two reasons: a case whose recipe vanished must report a
# failing assertion rather than a smaller assertion count, and every cookbook
# case — including ones added later — inherits the guard from the one boundary
# they all cross instead of restating it. R_STATUS/R_OUT/R_ERR are still set, so
# the assertions that follow read this call rather than the previous one's
# leftovers; 127 is "there was no command to run", which is what happened.
# shellcheck disable=SC2034
recipe_runner() {
  local opts="$1" dir="$2" script="$3"; shift 3
  local sh_bin="${R_SHELL:-$RECIPE_DEFAULT_SHELL}" awk_bin="${R_AWK:-$RECIPE_DEFAULT_AWK}"
  local loc="${R_LOCALE:-$RECIPE_DEFAULT_LOCALE}"
  local wrap shim path outf errf src ln
  if [ -z "$(printf '%s' "$script" | tr -d '[:space:]')" ]; then
    src="${BASH_SOURCE[2]:-?}"; ln="${BASH_LINENO[1]:-?}"
    t_fail "the recipe extracted to nothing — README.md has no such fenced block" \
      "an extractor returned empty text, so this case would have asserted against a recipe that does not exist" \
      "handed to ${FUNCNAME[1]} from ${src##*/}:$ln"
    R_STATUS=127; R_OUT=''; R_ERR=''
    return 0
  fi
  wrap="$(mktemp "$TMPROOT/recipe.XXXXXX")"
  { [ -z "$opts" ] || printf '%s\n' "$opts"; printf '%s\n' "$script"; } > "$wrap"

  path="$PATH"
  if [ -n "$awk_bin" ]; then
    shim="$TMPROOT/shim-$(basename "$awk_bin")"
    if [ ! -x "$shim/awk" ]; then mkdir -p "$shim"; ln -sf "$awk_bin" "$shim/awk"; fi
    path="$shim:$PATH"
  fi

  outf="$(mktemp "$TMPROOT/out.XXXXXX")"
  errf="$(mktemp "$TMPROOT/err.XXXXXX")"
  ( cd "$dir" && env PATH="$path" LC_ALL="$loc" "$@" "$sh_bin" "$wrap" ) \
    > "$outf" 2> "$errf" < /dev/null
  R_STATUS=$?
  R_OUT="$(cat "$outf")"
  R_ERR="$(cat "$errf")"
}

# The portability matrix. `matrix_awks` is a caller-settable subset because not
# every recipe runs awk at all.
#
# Every axis member is OPTIONAL and skipped when the machine does not have it:
# dash, gawk, mawk and nawk are all installable extras, and a suite that
# demanded them would contradict the convention it is testing. bash is the one
# member that is always present — the harness itself runs under it.
matrix_shells='bash dash'
matrix_awks='gawk mawk nawk'
matrix_locales='C C.utf8 en_US.utf8'

# locale_available <name> — true when the machine really has that locale.
#
# The declaration above is intent, not inventory: `C.utf8` and `en_US.utf8` are
# as installable as dash and mawk, and stock macOS ships neither (it spells the
# second `en_US.UTF-8`). Without this guard a leg is labelled with a locale it
# never entered — libc falls back to C behind a `setlocale` warning that lands in
# the leg's captured stderr — so the collation bug the axis exists to catch
# passes under it (SFT-0046).
#
# Probed by running the locale rather than by reading `locale -a`: `locale` is
# not on the BASELINE list in tests/static/suite-contract.test.sh, and that list
# is the suite's dependency contract. Probed through the harness's own bash and
# never through $R_SHELL, because whether a locale exists is a property of the
# machine and dash does not report a failed setlocale at all — probing through it
# would call a missing locale present for the whole dash half of the sweep.
#
# A missing locale is skipped, never swapped for an alias spelling: substituting
# `en_US.UTF-8` for `en_US.utf8` would label a leg with a locale it did not run
# under, which is the same fake-green one level down.
_locale_known=' '   # ' <name>=<0|1> ' pairs; the answer cannot change mid-run
locale_available() {  # locale_available <name>
  local loc="$1"
  # POSIX guarantees these two, so the sweep can never narrow to nothing.
  case "$loc" in C|POSIX) return 0 ;; esac
  case "$_locale_known" in
    *" $loc=1 "*) return 0 ;;
    *" $loc=0 "*) return 1 ;;
  esac
  if [ -z "$(env LC_ALL="$loc" bash -c true 2>&1)" ]; then
    _locale_known="$_locale_known$loc=1 "; return 0
  fi
  _locale_known="$_locale_known$loc=0 "; return 1
}

# --- The leg that is not a leg (SFT-0078) ------------------------------------
#
# Both sweeps below used to open with the combination `recipe_runner` already
# defaults to — `bash`/`C` and the PATH `awk` — so every sweep re-ran, on the
# fixture the plain case above it had just used, a claim that plain case had
# already made, and made it *worse*: a matrix callback collapses several
# conditions into one `t_ok`/`t_fail` whose failure output is a label rather than
# an expected/actual pair. That leg is excluded here. Nothing is narrowed: the
# exclusion removes ONE combination, never an axis member, so every shell, every
# awk and every locale the machine has is still entered by another leg.

# default_awk_bin — the awk a plain case really runs, resolved once.
#
# `command -v awk` is the answer, not the string `awk`: on most Linuxes
# /usr/bin/awk is a symlink into an alternatives farm, so which of gawk/mawk/nawk
# the default *is* is a property of the machine and cannot be written down here.
_default_awk_bin=''
default_awk_bin() {
  if [ -z "$_default_awk_bin" ]; then
    _default_awk_bin="$(command -v "${RECIPE_DEFAULT_AWK:-awk}" 2>/dev/null || true)"
    # A machine with no awk at all: nothing can equal the default, so no leg is
    # excluded — which is the right answer rather than a fallback.
    [ -n "$_default_awk_bin" ] || _default_awk_bin='/nonexistent/awk'
  fi
  printf '%s\n' "$_default_awk_bin"
}

# baseline_leg <shell> <locale> [awk-binary] — true when a leg would run in
# exactly the environment `recipe_runner` falls back to, so running it asserts
# nothing the plain case above the sweep has not already asserted.
#
# The awk argument is optional because `for_shell_locale` pins no awk: with
# R_AWK empty the leg runs the PATH awk by construction, which is the default by
# definition. When it IS pinned, the comparison is against the resolved binary
# and by inode (`-ef`) rather than by name — `bash/mawk/C` on a host whose `awk`
# is gawk is a genuinely different program from the plain case's and must keep
# running, while `bash/gawk/C` on that same host is the plain case again under
# another spelling.
baseline_leg() {  # baseline_leg <shell> <locale> [awk-binary]
  [ "$1" = "$RECIPE_DEFAULT_SHELL" ] || return 1
  [ "$2" = "$RECIPE_DEFAULT_LOCALE" ] || return 1
  if [ "$#" -ge 3 ]; then
    [ "$3" -ef "$(default_awk_bin)" ] || return 1
  fi
  return 0
}

# matrix_empty <callback> — a sweep with no leg left, said out loud.
#
# Excluding the baseline means a sweep CAN now come out empty: a host with no
# dash, no second awk and no UTF-8 locale has nothing left to vary. That is a
# narrowing of coverage down to the plain case, and the suite's rule is that a
# narrowed leg is named — so it goes through the harness's `skip`, where the
# `# SUMMARY … skipped=` count carries it into the run summary, rather than
# through a sweep that quietly asserts nothing.
matrix_empty() {  # matrix_empty <callback>
  skip "the $1 sweep, which has no combination left to vary" \
    "every member this machine has was narrowed away or is the excluded baseline $RECIPE_DEFAULT_SHELL/$RECIPE_DEFAULT_LOCALE on the awk PATH resolves"
}

# Matrix members are optional, but dropping one is still part of the result.
# Keep this channel separate from skip(): an absent member must not change
# assertion or skip counts, and one absent member may be encountered by many
# sweeps in one test file. (A sweep that absence empties completely is the one
# thing that IS counted, once, by `matrix_empty` above.) Both matrix entry
# points share this seen-set and emitter.
_matrix_narrowed_seen=' '
matrix_narrowed() {  # matrix_narrowed <axis> <member> <reason>
  local axis="$1" member="$2" reason="$3" key
  key="$axis/$member"
  case "$_matrix_narrowed_seen" in *" $key "*) return 0 ;; esac
  _matrix_narrowed_seen="$_matrix_narrowed_seen$key "
  printf '# NARROWED %s %s — %s\n' "$axis" "$member" "$reason"
}

# for_matrix <callback> [args…] — invoke callback once per combination, with
# R_SHELL / R_AWK / R_LOCALE set and R_LABEL naming the combination.
#
# R_LABEL is read only by the callbacks, which live in the test files that source
# this library — a cross-file read shellcheck cannot follow, unlike R_SHELL/R_AWK/
# R_LOCALE, which recipe_runner above reads in this same file.
# shellcheck disable=SC2034
for_matrix() {
  local cb="$1"; shift
  local sh a l bin legs=0
  for sh in $matrix_shells; do
    if ! command -v "$sh" > /dev/null 2>&1; then
      matrix_narrowed shell "$sh" "not installed"
      continue
    fi
    for a in $matrix_awks; do
      bin="$(command -v "$a" || true)"
      if [ -z "$bin" ]; then
        matrix_narrowed awk "$a" "not installed"
        continue
      fi
      for l in $matrix_locales; do
        if ! locale_available "$l"; then
          matrix_narrowed locale "$l" "not available"
          continue
        fi
        # After the availability guards, so an absent member is still recorded
        # on the narrowing channel before this one drops the repeat (SFT-0078).
        if baseline_leg "$sh" "$l" "$bin"; then continue; fi
        legs=$((legs + 1))
        R_SHELL="$sh"; R_AWK="$bin"; R_LOCALE="$l"; R_LABEL="$sh/$a/$l"
        "$cb" "$@"
      done
    done
  done
  R_SHELL="$RECIPE_DEFAULT_SHELL"; R_AWK="$RECIPE_DEFAULT_AWK"
  R_LOCALE="$RECIPE_DEFAULT_LOCALE"; R_LABEL=default
  [ "$legs" -gt 0 ] || matrix_empty "$cb"
}

# for_shell_locale <callback> [args…] — the same sweep for recipes built only
# from grep/sed/find, where the awk axis has nothing to vary.
#
# R_LABEL is read by the callbacks in the test files that source this library, a
# cross-file read the linter cannot follow — same contract as for_matrix above.
# shellcheck disable=SC2034
for_shell_locale() {
  local cb="$1"; shift
  local sh l legs=0
  for sh in $matrix_shells; do
    if ! command -v "$sh" > /dev/null 2>&1; then
      matrix_narrowed shell "$sh" "not installed"
      continue
    fi
    for l in $matrix_locales; do
      if ! locale_available "$l"; then
        matrix_narrowed locale "$l" "not available"
        continue
      fi
      # No awk is pinned here, so the excluded leg is bit-for-bit the plain
      # runner's environment and takes the two-argument form (SFT-0078).
      if baseline_leg "$sh" "$l"; then continue; fi
      legs=$((legs + 1))
      R_SHELL="$sh"; R_AWK=''; R_LOCALE="$l"; R_LABEL="$sh/$l"
      "$cb" "$@"
    done
  done
  R_SHELL="$RECIPE_DEFAULT_SHELL"; R_AWK="$RECIPE_DEFAULT_AWK"
  R_LOCALE="$RECIPE_DEFAULT_LOCALE"; R_LABEL=default
  [ "$legs" -gt 0 ] || matrix_empty "$cb"
}
