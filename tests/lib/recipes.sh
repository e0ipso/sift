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

# --- Running an extracted recipe --------------------------------------------
#
# run_recipe <workdir> <script-text> [VAR=VAL ...]
#
# Sets R_STATUS, R_OUT, R_ERR. Honours three knobs so one case can be replayed
# across the portability matrix:
#   R_SHELL  bash | dash          (default bash)
#   R_AWK    absolute awk path    (default: whatever PATH resolves)
#   R_LOCALE LC_ALL value         (default C)
#
# The block is run under `set -e`: the cookbook's guards are `… || { echo …;
# false; }` one-liners, and their documented "stops with the tree untouched"
# contract only holds when a failing command ends the run.
run_recipe() {
  local dir="$1" script="$2"; shift 2
  local sh_bin="${R_SHELL:-bash}" awk_bin="${R_AWK:-}" loc="${R_LOCALE:-C}"
  local wrap shim path outf errf
  wrap="$(mktemp "$TMPROOT/recipe.XXXXXX")"
  { echo 'set -e'; printf '%s\n' "$script"; } > "$wrap"

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

# for_matrix <callback> [args…] — invoke callback once per combination, with
# R_SHELL / R_AWK / R_LOCALE set and R_LABEL naming the combination.
for_matrix() {
  local cb="$1"; shift
  local sh a l bin
  for sh in $matrix_shells; do
    command -v "$sh" > /dev/null 2>&1 || continue
    for a in $matrix_awks; do
      bin="$(command -v "$a" || true)"
      [ -n "$bin" ] || continue
      for l in $matrix_locales; do
        R_SHELL="$sh"; R_AWK="$bin"; R_LOCALE="$l"; R_LABEL="$sh/$a/$l"
        "$cb" "$@"
      done
    done
  done
  R_SHELL=bash; R_AWK=''; R_LOCALE=C; R_LABEL=default
}

# for_shell_locale <callback> [args…] — the same sweep for recipes built only
# from grep/sed/find, where the awk axis has nothing to vary.
for_shell_locale() {
  local cb="$1"; shift
  local sh l
  for sh in $matrix_shells; do
    command -v "$sh" > /dev/null 2>&1 || continue
    for l in $matrix_locales; do
      R_SHELL="$sh"; R_AWK=''; R_LOCALE="$l"; R_LABEL="$sh/$l"
      "$cb" "$@"
    done
  done
  R_SHELL=bash; R_AWK=''; R_LOCALE=C; R_LABEL=default
}
