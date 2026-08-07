# Goal-gap analysis

The sweep measures one distance: what the project's own documents say the project is,
against what is actually on disk. Everything proposed is a gap in that distance and
nothing else. An improvement nobody has claimed to want is somebody else's backlog — the
value of this card is that the user recognises every row of the slate as their own stated
intent, unmet.

Phases 1–3 write nothing. The findings live in the orchestrator's context and in the chat
with the user; no file is created anywhere until the user agrees and drafting starts.

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

Every candidate carries one of exactly two citations:

- **`file:line`** — for a claim about something that exists.
- **`absent: <path>`** — for a claim about something that does not.

A candidate that can carry neither is **dropped**, not softened. Not reworded into a
vaguer form that no longer needs backing, not demoted to `p4` and kept: dropped.

Two things make that bar load-bearing rather than fussy. The convention already sets it —
rule 5 requires claims about code to cite `file:line`, and `## Evidence` is a required
body section. And the drafting agents downstream never saw the code: an agent handed a
candidate with no citation must either invent one or ship a body that fails rule 5, and
an invented citation is worse than a missing one because it reads authoritative.
Enforcing the bar at proposal time is the only moment when the agent that made the claim
is still the agent that can back it.

`absent: <path>` names the exact path checked. `absent: .github/workflows/` is a fact a
reader verifies in one command; "there is no CI" is a claim they have to take on trust.

## The scope fence

The user's optional prompt is a **hard scope fence**, never a priority hint and never a
theme. Fenced, the sweep looks only inside the fence. Unfenced, it runs at full breadth.

**Findings outside the fence become one closing line at the end of the run, never
tickets.** The user drew the fence to decide what enters their backlog; filing outside it
overrides that decision while appearing to serve them. The closing line preserves the
finding — they can re-run the card unfenced, or fence it there next time — without taking
the decision away from them.

The fence moves where the analysis looks. It never moves the evidence bar. A narrow fence
means fewer files read, not a lower standard for what those files have to prove, and
"there was not much in scope" is never a reason to let an uncitable candidate through.

## The sweep dimensions

The dimensions are the convention's closed `type` set, and they are named that way on
purpose: the dimension that found a candidate decides the candidate's `type`, and `type`
decides the category folder it will be written into. A finding that fits no dimension
fits no `type`, and there is nowhere on disk to put it.

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

The dimensions are swept independently for a reason. Converging on a single ticket is the
anti-pattern, not the tidy outcome, and there is no floor or target to hit either.
Findings arrive from several directions because several directions were looked in, and
what the user then agrees to is theirs to decide.

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

## Dedupe — before the user sees anything

```sh
scripts/existing-work.sh
```

One tab-separated line per ticket under `open/` and `archive/`, sorted by ID, with no
header line:

```
<ID><TAB><status><TAB><type><TAB><title><TAB><resolution>
```

`resolution` is empty for open tickets and carries the closing line for archived ones.
That last column is the reason the script exists: it is what separates "already filed"
from "already decided against". An empty backlog prints nothing and exits 0 — the
cold-tree case, not an error.

Check every candidate against that corpus before presenting anything. Three outcomes:

- **Already open** — drop it, and name the open ID when you present the slate. `blocked`
  and `in-progress` both live in `open/` and both count as already filed.
- **Already terminal** — drop it, and quote the archived ticket's `resolution` back to
  the user verbatim as the reason. They wrote that line; it answers the proposal better
  than any paraphrase of it.
- **Kept** — nothing in either bucket covers it.

**Re-proposing work already archived `wontfix` is the failure that ends the user's trust
in this card.** They spent the decision once and wrote the reason down; handing it back
as fresh work says the card did not read what they wrote. Re-rejecting costs them more
than the proposal was ever worth, and once they have seen it happen they read the whole
slate as noise and stop running the card. The `resolution` column exists to make that
impossible. Read it.

Match on subject matter, not on title strings. An archived ticket titled "Drop the
vendored parser" covers a candidate titled "Replace the bundled parser with the upstream
library"; the corpus is small enough to read every line of, so read every line of it.

## When the corpus and the sweep disagree

An open ticket whose evidence the sweep found has moved on — the cited line has changed,
the work is partly done — is not a candidate. It is an update to something that already
exists, and it goes to the user as a note beside the slate. This card writes new tickets;
it does not rewrite existing ones, and quietly proposing a duplicate of live work is the
same trust failure as re-proposing archived work, with a split ID space thrown in.
