# kenkeep Index: shell / awk

↑ Parent: [shell](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**An apostrophe in an embedded awk comment closes the shell string**](practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string.md) to learn about: Embedded awk programs are single-quoted shell strings, so a prose comment holding an apostrophe breaks the whole file at source time. #awk #shell #portability #gotcha #sift-drain
- Open [**Hand awk a value through ENVIRON, never through -v**](practice-hand-awk-a-value-through-environ-never-through-v.md) to learn about: awk's -v runs ANSI escape processing on its argument, so the two characters \\ and t arrive inside the program as one real tab; ENVIRON does not. #portability #awk #shell #gotcha #sift #convention
- Open [**Scope a front-matter rewrite to the fence, not just to the line start**](practice-scope-front-matter-rewrites-to-the-fence.md) to learn about: A ^key: anchor still matches body prose, and sed's 1,/^---$/ range runs to EOF on a fence-less file: walk the fence in awk with an in_fm flag instead. #sift #shell #gotcha #cookbook #convention
- Open [**An unset awk variable subscripts an array as "", never as 0**](practice-an-unset-awk-variable-subscripts-an-array-as-the-empty-string.md) to learn about: a\[x\] with x unassigned is a\[""\], a different cell from a\[0\], so a read before an increment and one after compare vacuously. #awk #shell #gotcha #testing #sift
- Open [**Strip a uniq -c count off the front of the line, never read it as a field**](practice-strip-a-uniq-c-count-off-the-front-never-read-it-as-a-field.md) to learn about: awk's $2 truncates the value at its first blank and the padding width shifts at ten; sub() the count away and keep $0. #portability #shell #gotcha #sift
- Open [**Tighten the selector with the pattern, or the loop keeps the wrong cell**](practice-tighten-the-selector-with-the-pattern-or-the-loop-keeps-the-wrong-cell.md) to learn about: Picking a field by the bare pattern survives every tightening of that pattern; select on the validated result instead. #awk #shell #sift #roadmap #gotcha

## Components (what exists)
_None yet._

## By topic

### #gotcha
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #shell
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Mutation probe a branch a later broader check would catch anyway**](../../testing/assertions/practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) — A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line.
### #awk
- Open [**An unset awk variable subscripts an array as "", never as 0**](practice-an-unset-awk-variable-subscripts-an-array-as-the-empty-string.md) — a\[x\] with x unassigned is a\[""\], a different cell from a\[0\], so a read before an increment and one after compare vacuously.
- Open [**Tighten the selector with the pattern, or the loop keeps the wrong cell**](practice-tighten-the-selector-with-the-pattern-or-the-loop-keeps-the-wrong-cell.md) — Picking a field by the bare pattern survives every tightening of that pattern; select on the validated result instead.
- Open [**Wrap a cookbook recipe in a subshell, never in bash -e -c**](../practice-wrap-a-cookbook-recipe-in-a-subshell-never-bash-e-c.md) — The recipes' guards only stop under set -e, and their single-quoted awk programs make bash -e -c an impossible wrapper.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-card comparison.
### #convention
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #cookbook
- Open [**Scope a front-matter rewrite to the fence, not just to the line start**](practice-scope-front-matter-rewrites-to-the-fence.md) — A ^key: anchor still matches body prose, and sed's 1,/^---$/ range runs to EOF on a fence-less file: walk the fence in awk with an in_fm flag instead.
- Open [**Report "nothing to compare" as its own finding, never as agreement**](../practice-report-nothing-to-compare-as-its-own-finding.md) — A check that reads a value then compares it has three outcomes: agree, disagree, and nothing read — and the third silently passes as the first.
- Open [**Guard a recipe before its first write, not before its last**](../writes/practice-guard-a-recipe-before-its-first-write-not-its-last.md) — A cookbook guard placed before mv still lets mkdir -p run; put every existence check ahead of the first command that touches the tree.
### #roadmap
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](../../tickets/practice-keep-roadmap-in-sync-same-change.md) — Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree.
- Open [**A roadmap row is its first ticket cell, not any mention of the ID**](../../cross-card/practice-a-roadmap-row-is-its-first-ticket-cell.md) — Only a table line's leftmost whole-token ID cell owns the row; a Needs, Title or prose mention is not one, and both cards must agree.
- Open [**Tighten the selector with the pattern, or the loop keeps the wrong cell**](practice-tighten-the-selector-with-the-pattern-or-the-loop-keeps-the-wrong-cell.md) — Picking a field by the bare pattern survives every tightening of that pattern; select on the validated result instead.
### #sift-drain
- Open [**Sub-agent autonomy is the contract in a sift drain**](../../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**When draining sift, orchestrate and never implement**](../../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**The drain orchestrator builds a wave graph of workers**](../../sift-drain/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #testing
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.