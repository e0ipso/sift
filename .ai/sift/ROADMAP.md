# Roadmap

Advisory resolution order. When this file and a ticket's `depends_on` disagree,
`depends_on` wins and this file is the thing that gets corrected.

A `~~struck~~` row is finished. Striking the row and archiving the ticket are ONE
change, in the same commit as the implementation (README.md, rule 9).

## Wave 1

| # | Ticket | Title | Needs |
|---|---|---|---|
| 1 | ~~SFT-0001~~ | ~~Reject path-traversing milestone names during Sift initialization~~ — done |  |
| 2 | ~~SFT-0002~~ | ~~Enforce the documented prefix character set during Sift initialization~~ — done |  |
| 3 | ~~SFT-0003~~ | ~~Make the cookbook allocate the next unused ticket ID~~ — done |  |
| 4 | ~~SFT-0004~~ | ~~Make the archive recipe update the roadmap row~~ — done |  |
| 5 | ~~SFT-0005~~ | ~~Ship the normative README through sift-init~~ — done |  |
| 6 | ~~SFT-0006~~ | ~~Automate synchronization of sift-init convention assets~~ — done | SFT-0005 |
| 7 | ~~SFT-0009~~ | ~~Widen cookbook ID extraction past four digits~~ — done |  |
| 8 | ~~SFT-0010~~ | ~~Stop the cookbook validation recipes reporting a clean tree when they read nothing~~ — done |  |
| 9 | ~~SFT-0011~~ | ~~Make the archive recipe create a missing resolution key~~ — done |  |
| 10 | ~~SFT-0012~~ | ~~Widen XSD ticketId pattern past four digits~~ — done | SFT-0009 |
| 11 | ~~SFT-0044~~ | ~~Stop sift-init.sh spinning forever on an option with no value~~ — done |  |
| 12 | ~~SFT-0045~~ | ~~Fail the run when a test file exits 0 without printing a SUMMARY line~~ — done |  |
| 13 | ~~SFT-0046~~ | ~~Guard the portability matrix's locale axis with an availability check~~ — done |  |
| 14 | ~~SFT-0047~~ | ~~Pin every claim a skill card's prose makes about a shipped file~~ — done |  |
| 15 | ~~SFT-0048~~ | ~~Close drain-log.sh's unasserted report and validation arms~~ — done |  |
| 16 | ~~SFT-0049~~ | ~~Cover sync-assets.sh's precondition refusals and its FAIL verdict~~ — done |  |
| 17 | ~~SFT-0050~~ | ~~Widen the drain's group-pass fixtures and sift-prime's shared sweep~~ — done |  |
| 18 | ~~SFT-0051~~ | ~~Hold suite-contract.test.sh to the suite's own documented promises~~ — done |  |
| 19 | ~~SFT-0052~~ | ~~Drive every normative fenced block in README.md from an extractor~~ — done |  |
| 20 | ~~SFT-0053~~ | ~~Let the fixtures produce the shapes the convention documents~~ — done |  |
| 21 | ~~SFT-0054~~ | ~~Give the XSD draft block a check that survives a machine without xmllint~~ — done |  |
| 22 | ~~SFT-0055~~ | ~~Add a cookbook recipe and test for the archived-resolution rule~~ — done |  |
| 23 | ~~SFT-0060~~ | ~~Stop a kenkeep hook's state file failing the suite's no-writes digest~~ — done |  |
| 24 | ~~SFT-0061~~ | ~~Draw config/ in README's directory-layout block~~ — done | SFT-0052 |

## Wave 2

| # | Ticket | Title | Needs |
|---|---|---|---|
| 1 | ~~SFT-0007~~ | ~~Add regression coverage for cookbook recipes~~ — done | SFT-0003, SFT-0004 |
| 2 | ~~SFT-0008~~ | ~~Add integration coverage for Sift workflow scripts~~ — done | SFT-0001, SFT-0002, SFT-0005 |
| 3 | ~~SFT-0013~~ | ~~Stop the front-matter validation recipe failing on a ticket-less tree~~ — done |  |
| 4 | ~~SFT-0014~~ | ~~Stop the per-milestone count inventing a milestone on an empty tree~~ — done |  |
| 5 | ~~SFT-0015~~ | ~~Stop the dependents recipe reporting tickets whose ID merely starts with the target~~ — done |  |
| 6 | ~~SFT-0016~~ | ~~Scope the archive and move substitutions to the front-matter block~~ — done |  |
| 7 | ~~SFT-0017~~ | ~~Reject unknown arguments in the drain selection helpers~~ — done |  |
| 8 | ~~SFT-0018~~ | ~~Give next-ticket.sh's run state a key of its own~~ — done |  |
| 9 | ~~SFT-0019~~ | ~~Cover the label helpers and the sift-prime write path~~ — done | SFT-0008 |
| 10 | ~~SFT-0020~~ | ~~Scope the folder/front-matter agreement check to the front-matter block~~ — done |  |
| 11 | ~~SFT-0021~~ | ~~Stop the move and archive recipes running on past a ticket that was never found~~ — done |  |
| 12 | ~~SFT-0022~~ | ~~Stop roadmap-append.sh refusing an ID that only appears as a blocker~~ — done |  |
| 13 | ~~SFT-0023~~ | ~~Stop list-labels.sh --counts truncating a label at its first blank~~ — done |  |
| 14 | ~~SFT-0024~~ | ~~Make the end-of-options marker work in tickets-by-label.sh~~ — done |  |
| 15 | ~~SFT-0025~~ | ~~Stop roadmap_rows truncating a ticket ID past four digits~~ — done |  |
| 16 | ~~SFT-0026~~ | ~~Make every cookbook fence walk agree on a trailing-space --- marker~~ — done |  |
| 17 | ~~SFT-0027~~ | ~~Say that the cookbook's guards only stop a run under set -e~~ — done |  |
| 18 | ~~SFT-0028~~ | ~~Stop the cookbook's per-label count truncating a label at its first blank~~ — done |  |
| 19 | ~~SFT-0029~~ | ~~Share one kebab-label validator between the two label scripts~~ — done |  |
| 20 | ~~SFT-0036~~ | ~~Make the shell-lint shellcheck arm pass now that the tool is installed~~ — done |  |
| 21 | ~~SFT-0056~~ | ~~Run tests/run.sh automatically on every change~~ — done | SFT-0045 |
| 22 | ~~SFT-0057~~ | ~~Name every skipped leg and narrowed matrix axis in run.sh's summary~~ — done | SFT-0045, SFT-0046 |
| 23 | ~~SFT-0058~~ | ~~Resolve the prompts' README rule-number citations against the rules themselves~~ — done | SFT-0047 |
| 24 | ~~SFT-0059~~ | ~~Cover every script write-failure arm with an unwritable-tree fixture~~ — done | SFT-0053 |
| 25 | ~~SFT-0062~~ | ~~Make the wave gate's e2e step serve a project with no browser~~ — done |  |
| 26 | ~~SFT-0063~~ | ~~Re-aim the two cases whose fixtures never reach the code they name~~ — done |  |
| 27 | ~~SFT-0064~~ | ~~Delete the two cases with no code of ours in the loop~~ — done |  |
| 28 | ~~SFT-0065~~ | ~~Move the fixture-only assertions out of the cookbook files~~ — done |  |
| 29 | ~~SFT-0066~~ | ~~Give tree_digest a positive control~~ — done |  |
| 30 | ~~SFT-0067~~ | ~~Drive the milestone validator under a UTF-8 locale~~ — done |  |
| 31 | ~~SFT-0068~~ | ~~Assert exactly one racing writer claims the tree~~ — done |  |
| 32 | ~~SFT-0069~~ | ~~Make shell-lint's loops report their own verdict and require a non-empty floor~~ — done |  |
| 33 | ~~SFT-0070~~ | ~~Snapshot the no-writes digest before the first run, and cover what each file drives~~ — done |  |
| 34 | ~~SFT-0071~~ | ~~Compare the filter recipe's parser copy too~~ — done |  |
| 35 | ~~SFT-0072~~ | ~~Pin make_tree against the tree sift-init.sh actually writes~~ — done |  |
| 36 | ~~SFT-0073~~ | ~~Delete the assertions that pin source spelling instead of behaviour~~ — done |  |
| 37 | ~~SFT-0075~~ | ~~Collapse the init and prime validator matrices to one row per guard branch~~ — done |  |
| 38 | ~~SFT-0076~~ | ~~Collapse the drain helpers' usage-exit permutations to one per option-loop branch~~ — done |  |
| 39 | ~~SFT-0077~~ | ~~Delete the per-recipe cases the file's own GUARDED sweep already covers~~ — done |  |
| 40 | ~~SFT-0078~~ | ~~Stop the portability matrices re-running the base case as their bash x C leg~~ — done |  |
| 41 | ~~SFT-0079~~ | ~~Hoist the duplicated fixture helpers into tests/lib~~ — done |  |
| 42 | ~~SFT-0080~~ | ~~Drive the prefix validator through a collated matcher~~ — done | SFT-0067 |
| 43 | ~~SFT-0081~~ | ~~Fail a cookbook case when its recipe extracts to nothing~~ — done |  |
| 44 | SFT-0082 | Decide whether .ai/sift is tracked, and make the tree agree |  |
| 45 | SFT-0083 | Collapse the matrix legs whose awk name resolves to a binary another leg already ran | SFT-0078 |

## Wave 3

| # | Ticket | Title | Needs |
|---|---|---|---|
| 1 | ~~SFT-0030~~ | ~~Make concurrent sift-init.sh runs survive each other~~ — done |  |
| 2 | ~~SFT-0031~~ | ~~Give roadmap_rows the left-hand whole-token guard roadmap-append.sh already has~~ — done |  |
| 3 | ~~SFT-0032~~ | ~~Give an already-installed .ai/sift/README.md a documented refresh path~~ — done |  |
| 4 | ~~SFT-0033~~ | ~~Honour the end-of-options marker in the rest of the sift-drain scripts~~ — done |  |
| 5 | ~~SFT-0034~~ | ~~Stop the cookbook's tree guard closing the shell it was pasted into~~ — done | SFT-0027 |
| 6 | ~~SFT-0035~~ | ~~Report an installed schema the card no longer ships~~ — done | SFT-0032 |
| 7 | ~~SFT-0037~~ | ~~list-labels.sh still hands awk the ticket path through -v~~ — done | SFT-0029 |
| 8 | ~~SFT-0038~~ | ~~Decide whether sift-drain and sift-prime may share one roadmap row reader~~ — done | SFT-0031 |
| 9 | ~~SFT-0039~~ | ~~drain-log.sh writes any string into the run log's ticket column~~ — done | SFT-0033 |
| 10 | ~~SFT-0040~~ | ~~drain-log.sh hands awk the run log path through -v~~ — done | SFT-0039 |
| 11 | ~~SFT-0041~~ | ~~Say the SFT-0038 decision in roadmap_rows' comment~~ — done | SFT-0038 |

## Wave 4

| # | Ticket | Title | Needs |
|---|---|---|---|
| 1 | ~~SFT-0042~~ | ~~Record the second cross-card rule — the ticket-ID shape~~ — done | SFT-0038 |
| 2 | ~~SFT-0043~~ | ~~Pin the line numbers AGENTS.md's duplication record cites~~ — done | SFT-0042 |
