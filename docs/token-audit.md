# Sift token audit, 2026-09-09

Follow-up: the [drain implementation and measured read trace](drain-context-measurement.md)
now address incremental reads, worker instruction reuse, staged references and bounded
output. The [prompt-caching implementation and experiment](drain-prompt-caching.md) address fresh
worker prefix reuse. The numbered findings below retain the original audit's baseline and proposal status.

Sift repeatedly pays for orientation, scheduling and verification around small units of
work. Shorter prose helps, but reducing repeated reads and unnecessary agent turns should
produce larger savings. The strongest remaining candidates are Prime's overlapping sweeps,
the knowledge catalog, and duplicate full-suite verification at wave boundaries.

This audit covers all three shipped skill entrypoints and their five reference files,
the normative README and schemas, selection and dedupe helpers, worker and gate handoffs,
and this repository's agent instructions and knowledge navigation. Kenkeep and Strikethroo
are separate installed tools; their local context costs are distinguished below from
Sift's shipped behavior. Their bundled implementations were not audited in full.

Measurements are character and whitespace-delimited word counts, not billed tokens. The
60 saved Kenkeep session captures contain no JSON input/output/cache token usage fields.
They cannot establish model reasoning costs, cache hits or total spend. Separate host logs
under `/home/node/.codex/sessions` do contain per-response `token_usage_record` counters.
Those counters were discovered after this audit and were not collected by the shell trace. The historical
[batching plan](../.ai/strikethroo/archive/03--sift-drain-batched-dispatch-and-fixed-cost/plan-03--sift-drain-batched-dispatch-and-fixed-cost.md)
contains wall-clock estimates, which are not token measurements and are not reused here.

The baseline before this change contained:

| Input | Characters | When it is paid |
|---|---:|---|
| Drain entrypoint | 8,673 | Coordinator loads the skill |
| Drain run management | 3,574 | Coordinator plans sittings |
| Worker reference, including template metadata and recovery prompts | 12,072 | Coordinator loads the reference |
| Actual initial worker template | 7,599 | Every fresh implementation sitting, before task inputs |
| Wave-gate reference, containing four agent prompts | 8,623 | Coordinator loads the gate instructions |
| Prime entrypoint and analysis reference | 10,446 | Prime coordinator orientation |
| Drafting reference / actual drafting template | 6,206 / 4,169 | Coordinator / each fresh drafting batch |
| Init entrypoint | 8,630 | Initialization or repair |
| All eight shipped instruction files | 58,224 | Inventory total, not one mandatory context load |

These sizes exclude injected system instructions, tool schemas, source reads, tickets,
knowledge leaves, tool results and generated reasoning. Shared files on disk do not imply
shared model context across fresh agents. Prompt caching may reduce charged input cost;
these measurements do not establish whether caching occurred.

1. **Repeated full-wave ticket reads. Fixed in this change.**
   [Drain's wave loop](../src/skills/sift-drain/SKILL.md) previously required reading every
   remaining current-wave ticket before every dispatch. With N unchanged tickets completed
   one at a time, that requests N(N+1)/2 ticket-body reads. Twenty tickets mean 210 reads
   instead of 20. In five sequential sittings of four tickets, it means 60 instead of 20.
   Those examples save 90.5% and 66.7% of these body reads respectively, not of total tokens.

   The loop now reads the wave once and compares content/path snapshots before dispatch.
   Only added or changed relevant tickets need another body read. Moves, archives, removed
   tickets and changed dependency targets update the graph. A new wave or lost context
   requires a fresh load. The new [snapshot helper](../src/skills/sift-drain/scripts/ticket-snapshot.sh)
   uses standard `find`, `cksum` and `sort`; snapshots live outside tracker state and are
   compared in the shell. It still reads ticket bytes from disk, including the archive.
   The saving is model input, not filesystem I/O. Checksums are change hints, not locks or
   an atomic view of concurrent writes. Failed scans must never promote a partial snapshot.

2. **Mandatory seven-way Prime sweep. High expected impact; proposed.**
   [analysis.md](../src/skills/sift-prime/references/analysis.md), line 60, requires one agent
   per dimension for an unfenced run. Bug, hardening, feature, test, docs, dx and release are
   finding classifications that often require reading the same source. Seven agents can
   repeat project orientation and inspect overlapping files before the coordinator dedupes
   their findings. The instructions establish the duplication risk; logs here do not measure
   how often all seven agents actually reread a particular file.

   Partition by component or directory when the repository is large, and have each sweep
   cover all seven dimensions within its assigned component. Use one sweep for a small
   repository. Give cross-component contracts one explicit owner. Preserve full breadth,
   the user's scope fence, and the evidence bar. Validate with a fixture containing known
   cross-component defects and compare distinct files read, duplicated bytes and findings
   retained. This changes the analysis workflow and deserves behavioral evaluation.

3. **Knowledge indexes approach the size of the knowledge itself. High local impact; proposed.**
   This repository has 22 generated index files totaling 22,802 words and 97 leaves totaling
   28,667 words. Indexes are 44.3% of their combined word count. The
   [orchestration index](../.ai/kenkeep/nodes/sift-drain/orchestration/index.md) alone contains
   1,247 words. One [rewrite-testing leaf](../.ai/kenkeep/nodes/testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md)
   appears 51 times across the indexes, often under several topic lists on the same page.
   This is repeated navigation text before the agent reaches useful knowledge.

   Change the owning Kenkeep index generator to emit each local link once with a short
   description, list child folders once, and expose cross-links only when needed. Remove
   repeated navigation boilerplate below the entrypoint. Measure paths-to-answer and bytes
   read for representative tasks, preserving discovery of relevant cross-component rules.
   Hand-trimming generated indexes would not survive regeneration. This is a local
   Kenkeep cost amplified by Sift's worker-orientation rule, not a universal installed-Sift
   size. Do not disable project knowledge requirements to hide it.

4. **Fresh workers repeatedly load the same project context. High expected impact; proposed.**
   [Worker orientation](../src/skills/sift-drain/references/ticket-agent-prompt.md), line 72,
   loads project instructions, includes and knowledge navigation in every fresh sitting.
   Before this change, one illustrative route through this repository's AGENTS, ENTRY,
   drain index, orchestration index, worker template and three required spec sections
   totaled 33,446 characters before ticket bodies, knowledge leaves or product source.
   That route is relevant to orchestration work; other ticket types take other branches.

   Prefer the already-supported reuse of a worker for related follow-ups within a wave.
   Tell reused workers to retain unchanged instructions and reload changed files or lost
   context. Supply applicable knowledge paths and discovered test commands in the initial
   assignment so workers can reach them directly while honoring project entry requirements.
   Keep fresh contexts for unrelated tasks. Record context size as well as reuse counts;
   endlessly growing a worker transcript can erase the saving.

5. **Several full-suite owners at the wave gate. High potential cost; proposed.**
   [wave-gate.md](../src/skills/sift-drain/references/wave-gate.md) asks the e2e author for a
   full e2e run at line 29, coverage for every full suite at line 75, fix agents for affected
   full suites at line 118, and close for all full checks at line 179. The
   [entrypoint](../src/skills/sift-drain/SKILL.md) also requires integrated full verification.
   Runs after code or environment changes can be necessary. Repeating a green run on the
   same effective tree and environment solely because another phase began is avoidable.

   Assign one final integrated verification owner. Authors run scoped checks; final close
   runs all required suites after landings. Reuse evidence only when tested tree, command,
   configuration and environment match; rerun after relevant changes or uncertainty.
   Do not weaken the existing integrated verification requirement. Measure suite executions
   and log bytes separately: a long-running quiet test consumes time without necessarily
   consuming many model tokens. This proposal needs workflow tests across successful and
   failing gates before adoption.

6. **Ticket-writing spec reads on workers that never write tickets. Reduced here.**
   The worker used to load Rules for agents, Front-matter schema and Ticket body during
   every orientation. The latter two total 2,121 characters. They are now conditional on
   creating follow-ups or changing those conventions. Drafting a ticket is also explicitly
   loaded before a follow-up. Ordinary implementation still reads Rules for agents and its
   assigned tickets. This moves the read to the decision that needs it; it does not relax
   the drafting contract. Conditional instructions add some prompt text, so 2,121 is the
   avoided spec read, not the net reduction across every worker invocation.

7. **Whole worker reports forwarded to knowledge capture. Reduced here.**
   [The capture handoff](../src/skills/sift-drain/references/wave-gate.md), line 140,
   previously supplied all collected worker reports. At twenty reports of 250 words each,
   that could forward 5,000 words of status, verification and bookkeeping alongside a few
   durable candidates. The handoff now selects candidate excerpts with IDs, citations and
   relevant decisions. Evidence remains available to verify against the live tree. Savings
   depend on actual report sizes and candidate counts; 5,000 words is an illustration.

8. **Coordinator and worker both search history. Medium impact; proposed.**
   [run-management.md](../src/skills/sift-drain/references/run-management.md), line 21,
   tells the coordinator to check integration history and branch names. The
   [worker](../src/skills/sift-drain/references/ticket-agent-prompt.md), line 78, separately
   runs `git log --oneline -30` and `git branch --list`. Pass the checked base commit and
   matching prior-work references with the assignment. Let the worker verify live behavior
   and search again only when the supplied check is absent, stale or inconclusive. A
   history match alone must never establish that the ticket is already implemented.

9. **Every metadata omission can trigger another agent turn. Medium impact; proposed.**
   [Report consumption](../src/skills/sift-drain/references/run-management.md), line 99,
   requires sending incomplete fields or numbers back to the author. The worker report
   asks for exact tests and assertion counts even though some runners expose only one of
   those. A successful result can therefore cause a follow-up merely to explain an absent
   counter. Accept `not reported by runner` for unavailable counts; require return trips
   for missing commit, status, acceptance evidence or other facts that affect landing.
   Keep errors distinct from unavailable counters. Measure correction turns by reason.

10. **Repeated verification within a multi-ticket sitting. Medium impact; proposed.**
    [Worker steps 3c and 4](../src/skills/sift-drain/references/ticket-agent-prompt.md) run
    each ticket's scoped checks and then their union. The existing one-ticket reuse rule is
    good. For a multi-ticket sitting, preserve earlier results when later changes do not
    invalidate their tested files or dependencies, then run missing checks. Shared code
    changes still invalidate earlier evidence. Start with explicit independence rather than
    implementing a speculative dependency cache. Project-required full checks take priority.

11. **Gate model selection ignores task size. Cost opportunity; proposed.**
    [Gate sections 1 and 2](../src/skills/sift-drain/references/wave-gate.md) say to use a
    strong model unconditionally. That differs from the drain entrypoint's task-based
    selection. Apply the same complexity and verification criteria to gates. A difficult
    integration investigation warrants a strong model; executing known commands and
    summarizing results may not. This affects price and possibly reasoning length, not
    guaranteed input-token count. Honor session preferences and benchmark retained quality.

12. **Per-finding dedupe queries and mandatory alternate searches. Medium at scale; proposed.**
    [Prime dedupe](../src/skills/sift-prime/references/analysis.md), line 104, queries every
    survivor separately and directs alternate wording after an empty result. With many
    related candidates, the same corpus and matching rows recur. Add a batch query format
    with independent query IDs and per-query limits, and reuse identical query results until
    tickets change. Preserve the current 25-row cap, overflow warning and resolution
    truncation marker in [existing-work.sh](../src/skills/sift-prime/scripts/existing-work.sh).
    A global result cap could silently starve later candidates. Empty search results still
    require judgment; do not treat them as proof of novelty.

13. **Resume can require repeating the whole Prime analysis. High for interrupted runs; proposed.**
    [analysis.md](../src/skills/sift-prime/references/analysis.md), final section, prohibits
    scratch findings before approval and explicitly says to rerun analysis if the session
    ends. Permit an optional local analysis checkpoint, clearly separate from approved
    tickets, recording scope, evidence and source fingerprints. Revalidate changed sources
    on resume. This changes the deliberate chat-only negotiation policy and should be
    decided explicitly; the audit does not introduce checkpoint files into the tracker.

14. **Verbose descriptions and maintenance pins occupy runtime prompts. Smaller, broad impact; proposed.**
    The baseline drain entrypoint contains 1,659 characters of `@PIN` lines, about 19% of
    that file. They support repository tests but provide little dispatch guidance. Move
    maintainers' pin inventories to a sidecar read by the tests, preserving their checks.
    Skill descriptions also repeat trigger synonyms, especially Init. Shorten descriptions
    while retaining distinctions between initialization, priming and draining. Descriptions
    can enter skill-discovery context even when the skill body is not loaded.

15. **Stale knowledge creates conflicting work. Medium local impact; proposed.**
    The [ignored-tracker note](../.ai/kenkeep/nodes/sift-drain/tracker-runtime/practice-account-for-ai-sift-being-gitignored.md)
    still prescribes rereading `ROADMAP.md` and running `roadmap-check.sh`. The
    [ownership note](../.ai/kenkeep/nodes/sift-drain/orchestration/practice-the-drain-orchestrator-owns-tracker-writes.md)
    also describes roadmap row writes. Those conflict with the current ticket-wave model.
    Agents may spend turns searching for retired files or reconciling two instructions.
    Update those leaves through Kenkeep and regenerate their indexes. Keep the reason for
    checking ignored files, but point to current operations instead of copying their full
    workflow. Audit other high-traffic leaves for obsolete commands in the same pass.

16. **Fixed orchestration and test-deferral costs on small tasks. Potentially high; design choice.**
    [Prime and Drain](../src/skills/sift-drain/SKILL.md) require coordinator/worker separation;
    implementation workers also defer new tests to a fresh gate worker. A tiny ticket can
    pay for a worktree, several phase commands, implementation orientation, another agent's
    coverage orientation and report handoffs. Related sittings already reduce that cost.
    First improve batching and measure tickets per sitting. Then evaluate whether small
    coherent fixes should include their own focused regression test, or whether an explicit
    small-task execution mode is useful. Preserve ownership, verification and independent
    review where needed. Removing delegation everywhere would sacrifice useful isolation.

17. **Tool output and large file reads remain an uncontrolled input cost. Cross-cutting; proposed.**
    `wave-status.sh` prints every wave and every remaining current-wave title each time;
    `next-ticket.sh --group` can repeat much of that list. Offer a compact dispatch report
    with deltas and retain full status for initial orientation and user summaries. Preserve
    blocked/unkeyed diagnostics. Do not cap silently. For test execution, save raw output
    to a temporary log and expose the exit status, summary and relevant failures.

    Broad searches of bundled code or entire knowledge trees can produce truncated output
    and trigger a second read. Use file discovery or counts first, then bounded source
    reads. Execute shipped helpers without reading their implementations unless debugging
    or changing them. A shell-side scan is not itself model-token usage; printing its
    entire result is. This audit also encountered oversized exploratory search output,
    illustrating that tool-call discipline matters alongside the shipped instructions.

18. **More findings can create more future work. Medium impact; proposed.**
    [Prime plurality](../src/skills/sift-prime/references/analysis.md), line 80, requests
    every qualifying candidate, and [reporting](../src/skills/sift-drain/references/run-management.md)
    repeats every self-filed ID. The evidence bar prevents invented defects, but a long
    slate of low-value maintenance issues still costs negotiation, drafting and later
    dispatches. Preserve the user's choice of ticket count. Offer an impact threshold or
    explicitly scoped review when requested, merge only under the existing one-Direction
    rule, and keep complete filed-ticket inventories at wave/run boundaries. Routine
    progress can report newly filed IDs instead of repeating the cumulative list.

The three implemented reductions are intentionally narrow. The snapshot instructions add
one-time coordinator text and a shell scan to avoid repeated ticket-body input. No ticket
shape, lifecycle, installed asset or RUNLOG format changes, and no migration is required.
The new helper tests exercise stable snapshots, same-size edits with preserved dates,
renames, archiving, additions, removals, archived dependency changes, empty trees and scan
failures. Root-resolution coverage includes the new helper. Static section checks validate
the conditional spec references. These checks cannot prove that a model will follow the
new read policy or quantify an end-to-end saving.

For the next measured cleanup, prioritize component-based Prime sweeps, compact Kenkeep
indexes and one authoritative final verification run. Record optional harness usage outside
ticket state: agent role, sitting IDs, model, input/cached/output/reasoning tokens when
available, tool-result bytes, duplicate file reads, verification commands and correction
turns. Missing counters should remain unknown. RUNLOG's timestamps cannot supply them.
Use the same isolated fixture backlog, starting tree, model and settings for before/after
trials; compare completed acceptance criteria and defects retained alongside token totals.
Separate initial requests from subsequent dispatches, alternate repeated variants, and
record cache warmth and routing uncertainty. Do not label an initial request a guaranteed
cold-cache request. Do not set token targets by dropping required evidence or verification.

Reproduce the basic inventory from the repository root with Unix tools:

```sh
wc -m -w src/skills/*/SKILL.md src/skills/*/references/*.md
find .ai/kenkeep/nodes -name index.md -exec cat {} + | wc -w
find .ai/kenkeep/nodes -name '*.md' ! -name index.md -exec cat {} + | wc -w
```

The table records the pre-change baseline. Later runs include this patch's added refresh
instructions and conditional reads. Exact model tokenization requires the tokenizer for
the actual model; file sizes alone cannot provide a billing total.
