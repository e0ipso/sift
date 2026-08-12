# kenkeep Index: shell

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
- Load [`awk/`](awk/index.md) for more information on awk-specific rules — embedded-program quoting, ENVIRON hand-off, field splitting and fence walking; read when writing or editing an embedded awk program.
- Load [`writes/`](writes/index.md) for more information on writing into the tree safely — create-if-absent semantics, atomic publication, guard ordering and write-boundary validation; read when a recipe or script creates, replaces or moves a file.

## Conventions (how we build)
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) to learn about: grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read. #portability #shell #gotcha #sift #convention
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) to learn about: A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt. #portability #shell #gotcha #sift #convention
- Open [**Report "nothing to compare" as its own finding, never as agreement**](practice-report-nothing-to-compare-as-its-own-finding.md) to learn about: A check that reads a value then compares it has three outcomes: agree, disagree, and nothing read — and the third silently passes as the first. #sift #shell #gotcha #cookbook #convention
- Open [**Wrap a cookbook recipe in a subshell, never in bash -e -c**](practice-wrap-a-cookbook-recipe-in-a-subshell-never-bash-e-c.md) to learn about: The recipes' guards only stop under set -e, and their single-quoted awk programs make bash -e -c an impossible wrapper. #sift #shell #cookbook #awk #gotcha

## Components (what exists)
_None yet._

## By topic

### #gotcha
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #shell
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #convention
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #cookbook
- Open [**Scope a front-matter rewrite to the fence, not just to the line start**](awk/practice-scope-front-matter-rewrites-to-the-fence.md) — A ^key: anchor still matches body prose, and sed's 1,/^---$/ range runs to EOF on a fence-less file: walk the fence in awk with an in_fm flag instead.
- Open [**Report "nothing to compare" as its own finding, never as agreement**](practice-report-nothing-to-compare-as-its-own-finding.md) — A check that reads a value then compares it has three outcomes: agree, disagree, and nothing read — and the third silently passes as the first.
- Open [**Guard a recipe before its first write, not before its last**](writes/practice-guard-a-recipe-before-its-first-write-not-its-last.md) — A cookbook guard placed before mv still lets mkdir -p run; put every existence check ahead of the first command that touches the tree.
### #portability
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #awk
- Open [**Hand awk a value through ENVIRON, never through -v**](awk/practice-hand-awk-a-value-through-environ-never-through-v.md) — awk's -v runs ANSI escape processing on its argument, so the two characters \\ and t arrive inside the program as one real tab; ENVIRON does not.
- Open [**Tighten the selector with the pattern, or the loop keeps the wrong cell**](awk/practice-tighten-the-selector-with-the-pattern-or-the-loop-keeps-the-wrong-cell.md) — Picking a field by the bare pattern survives every tightening of that pattern; select on the validated result instead.
- Open [**Wrap a cookbook recipe in a subshell, never in bash -e -c**](practice-wrap-a-cookbook-recipe-in-a-subshell-never-bash-e-c.md) — The recipes' guards only stop under set -e, and their single-quoted awk programs make bash -e -c an impossible wrapper.