# Goal-gap analysis

The sweep measures one distance: what the project's own documents say the project is,
against what is actually on disk. Everything proposed is a gap in that distance and
nothing else. An improvement nobody has claimed to want is somebody else's backlog — the
value of this skill is that the user recognises every row of the slate as their own stated
intent, unmet.

## Sources of stated intent

These four, in this order, are what the sweep is allowed to measure against:

1. **The repository `README.md`** — what the project claims it does, for whom.
2. **`AGENTS.md` / `CLAUDE.md` and every file they include.** The rules the project binds
   its agents to are intent in its strongest form: a rule stated there and unenforced on
   disk is a gap the project has already agreed exists.
3. **`.ai/sift/MILESTONES.md`** — where the project says it is going next, and the names
   the agreed work will have to slot into.
4. **The knowledge base, if the project ships one** — its entry catalog or index first,
   then the entries the fence or the dimension touches.

Nothing else is intent. A framework's best practice, a linter default the project never
adopted, an architecture you would have chosen instead: these are opinions, and opinions
are what the evidence bar exists to keep out of the slate.

## The evidence bar

Where this section restates a rule of the convention, an `@RULE: <repo-root-relative
file> <N> <verbatim rule substring>` marker sits in a fence beside the sentence making
the claim — that marker is where the ordinal lives, so the sentence itself can say what
the rule requires. `tests/static/readme-rule-citations.test.sh` extracts each marker and
resolves the cited ordinal against README's bounded `## Rules for agents` list.

Every citation on a candidate uses exactly one of two formats:

- **`file:line`** — for a claim about something that exists.
- **`absent: <path>`** — for a claim about something that does not.

A candidate that can carry neither is dropped. Do not reword it to avoid the evidence bar
or keep it at a lower priority. The convention already requires code claims to cite
`file:line`; the drafting agent cannot repair a missing citation because it never read the
code.

```text
@RULE: README.md 5 Claims about code cite
```

`absent: <path>` names the exact path checked. For example,
`absent: .github/workflows/` is verifiable; "there is no CI" is not.

## The scope fence

The user's optional prompt is a **hard scope fence**, never a priority hint and never a
theme. Fenced, the sweep reads and reports only inside the declared fence. Its report may
state that the run was fenced and name the scope inspected, but every finding and citation
comes from that scope; it makes no claim about paths it did not inspect. Unfenced, the sweep
runs at full breadth across the stated-intent sources and all seven dimensions.

The fence moves where the analysis looks. It never moves the evidence bar. A narrow fence
means fewer files read, not a lower standard for what those files have to prove, and
"there was not much in scope" is never a reason to let an uncitable candidate through.

The paired markers below are machine-read by
`tests/static/prime-scope-contract.test.sh`. The test holds every restatement to the same
read-and-report boundary and rejects a fenced contract that also asks for findings from
uninspected paths.

```text
@PRIME-SCOPE: fenced reads-and-reports-inside
@PRIME-SCOPE: unfenced full-breadth
```

## The sweep dimensions

The dimensions are the convention's closed `type` set, and they are named that way on
purpose: the dimension that found a candidate decides the candidate's `type`, and `type`
decides the category folder it will be written into. A finding that fits no dimension
fits no `type`, and there is nowhere on disk to put it.

That makes the `Dimension` column below a restatement of the convention's own set, so it is
pinned to it: the line below names the file and the verbatim construct that has to still be
there, and `tests/static/skill-prose-pins.test.sh` extracts it and fails when the set has
changed underneath this table. Add or drop a dimension only together with the convention.

```text
@PIN: README.md bug | hardening | feature | test | docs | dx | release
```

| Dimension | What it looks for | Usual citation |
|---|---|---|
| `bug` | behaviour on disk contradicting what the docs, the tests or the code's own comments say it does | `file:line` |
| `hardening` | unvalidated input, a missing error path, a portability trap, a guard the project's rules demand and the code omits | `file:line` |
| `feature` | capability the documents promise or the milestones require, with nothing behind it | `absent: <path>` |
| `test` | behaviour whose breakage no assertion would catch; suites that skip what they claim to cover | `absent: <path>` |
| `docs` | documented behaviour that has drifted from the code; public surface nothing describes | either |
| `dx` | friction in the project's own workflow — a step every contributor repeats by hand that nothing scripts | either |
| `release` | packaging, versioning, registration and distribution the project claims but has not wired | `absent: <path>` |

**One read-only sub-agent per dimension** — or per slice of the fence when the run is
fenced, because seven dimension agents against a three-file fence is seven readings of
the same three files. Sweep agents read. They write nothing, edit nothing, and run no
`git` command that changes state.

**The orchestrator reads their reports, never the source.** Sweeping a repository inline
buries the orchestrator's context in exactly the material it delegated away, and the
orchestrate-never-implement discipline `sift-drain` holds applies here without amendment.

`.ai/sift` is gitignored by default, so ignore-aware search silently returns nothing from
it. Sweep agents that look inside the tree use `find` plus `command grep`.

## What a finding looks like when it reaches the orchestrator

Sweep agents return findings in this shape and nothing else — no source excerpts, no
diffs, no narration of what they read:

```
finding:  <imperative title>
type:     bug | hardening | feature | test | docs | dx | release
why:      <one line: what is wrong or missing, and who it costs>
evidence: <file:line, or absent: <path> — one or more>
```

That is the whole handoff, and each line has a destination. `why` becomes the slate row's
rationale and the seed of `## Problem`. `evidence` is carried verbatim into `## Evidence`
by the drafting agent, which is why it has to be right here rather than plausible here.

## Plurality

Propose a slate, not a single-ticket target. Independent dimensions may yield several
candidates, but there is no floor, quota or target count. The user decides how many survive
negotiation.

## Clustering rules

Cluster by root cause after the evidence bar and before dedupe. This step decides ticket
boundaries; milestone planning later groups survivors by outcome. A merged candidate
remains one problem with several sites.

### The one-Direction test

A cluster is valid only when one `## Direction` applies unchanged to every member site.
Shared symptoms do not qualify. Write the Direction to test the merge; if any site needs a
different action, keep it separate.

### One citation per site

A clustered candidate keeps one `file:line` citation per site, and its slate row shows every
site with its citation. A member without its own citation is dropped under the evidence bar.
The user may split the row, drop a site or merge rows during negotiation.

### Split tickets keep the cluster

Members with different Directions or milestones stay in separate tickets. If they still
share one root cause, give each ticket the same optional kebab-case `cluster` value so
`sift-drain` can group them at dispatch. A shared symptom without a shared root cause gets
separate tickets and no `cluster` key.

## Dedupe

```sh
scripts/existing-work.sh
```

The script prints one tab-separated line per ticket under `open/` and `archive/`, sorted by
ID, with no header line:

```
<ID><TAB><status><TAB><type><TAB><title><TAB><resolution>
```

`resolution` is empty for open tickets and carries the closing line for archived ones. An
empty backlog prints nothing and exits 0.

Before presenting the slate, compare every candidate's subject matter, not just its title,
against both buckets:

- **Already open** — drop it, and name the open ID when you present the slate. `blocked`
  and `in-progress` both live in `open/` and both count as already filed.
- **Already terminal** — drop it, and quote the archived ticket's `resolution` verbatim,
  including a `wontfix` decision.
- **Kept** — nothing in either bucket covers it.

## When the corpus and the sweep disagree

An open ticket whose evidence has moved on is not a new candidate. Report the change as a
note beside the slate; this skill does not rewrite existing tickets.

## Chat-only negotiation

Keep findings and the proposed slate in the orchestrator's context and in the conversation.
Before the user approves the slate, create no files anywhere: no scratch slate, `.prime/`
directory, draft or other artifact under `.ai/sift`. If the session stops before approval,
rerun the analysis. File writes begin only with the approved drafting phase.
