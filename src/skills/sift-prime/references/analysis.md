# Goal-gap analysis

The sweep measures one distance: what the project's own documents say the project is,
against what is actually on disk. Everything proposed is a gap in that distance and
nothing else. An improvement nobody has claimed to want is somebody else's backlog — the
value of this skill is that the user recognises every row of the slate as their own stated
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

Where this section restates a rule of the convention, an `@RULE: <repo-root-relative
file> <N> <verbatim rule substring>` marker sits in a fence beside the sentence making
the claim — that marker is where the ordinal lives, so the sentence itself can say what
the rule requires. `tests/static/readme-rule-citations.test.sh` extracts each marker and
resolves the cited ordinal against README's bounded `## Rules for agents` list.

Every candidate carries one of exactly two citations:

- **`file:line`** — for a claim about something that exists.
- **`absent: <path>`** — for a claim about something that does not.

A candidate that can carry neither is **dropped**, not softened. Not reworded into a
vaguer form that no longer needs backing, not demoted to `p4` and kept: dropped.

Two things make that bar load-bearing rather than fussy. The convention already sets it:
claims about code cite `file:line`, and `## Evidence` is a required body section.

```text
@RULE: README.md 5 Claims about code cite
```

And the drafting agents downstream never saw the code: an agent handed a candidate with
no citation must either invent one or ship a body with no evidence at all, and an invented
citation is worse than a missing one because it reads authoritative.

```text
@RULE: README.md 5 Claims about code cite
```

Enforcing the bar at proposal time is the only moment when the agent that made the claim
is still the agent that can back it.

`absent: <path>` names the exact path checked. `absent: .github/workflows/` is a fact a
reader verifies in one command; "there is no CI" is a claim they have to take on trust.

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

## Clustering — one defect, many sites

A defect that appears at five call sites is **one** candidate carrying five citations, not
five candidates carrying one each. No sweep agent can see that: each reads its own
dimension, or its own slice of the fence, and reports what is in front of it. The
orchestrator is the only reader that holds every finding at once, so the collapse happens
here — after the evidence bar has already discarded whatever nothing backs, and before
dedupe, so the thing dedupe compares against live work is the clustered candidate rather
than its fragments.

This step clusters by **root cause**, and it decides how many tickets get written. It is
not the milestone pass, which groups the survivors by the outcome they deliver.

### The test for a valid cluster

**A cluster is valid only when one `## Direction` covers every member site: one statement
of approach, applied unchanged at each site, resolves all of them. Shared fix shape, not
shared symptom. A candidate that cannot state one such Direction stays split.**

Apply the test by actually writing the sentence. If it needs an "and at the third site,
instead …", that is two Directions and therefore two tickets. Two recipes that both report
a clean tree when they read nothing share a symptom exactly, and are still not one cluster
if one needs an existence guard and the other needs a different query.

**Merge wrongly and a drafting agent invents the Direction.** It never saw the code: it has
a title, a one-line `why`, and the citations handed to it. Given members that do not share
a fix it cannot write a Direction covering them, and it will not report the contradiction —
it will write something plausible. `sift-drain` then reads `## Direction` as the
implementing agent's brief, so the invention lands two skills downstream on an agent with no
way to know it was invented. A split that should have been a merge costs one extra row on
the slate. A merge that should have been a split costs a ticket whose brief is fiction.

None of this bends the one-problem-per-ticket rule. One file is still one problem: a
cluster is one problem with several manifestations, never several problems in one file. A
member that is its own problem was never a member.

### The citations survive the merge

`## Evidence` on a clustered candidate is a list, not a line — **one `file:line` citation
per site**, every site, with none of them folded into a representative example.

**Dropping a site's citation to tidy the list is the same failure as inventing one.** An
invented citation puts a claim in the ticket that nothing backs; a dropped one puts a site
in the fix that nothing points at. Both mislead the same reader, the agent that implements
the ticket without ever seeing this run, and that agent fixes what the ticket cites. An
uncited site is outside the ticket whatever the title implies, and it returns as a fresh
finding on some later run, stripped of the context that would have explained it.

The bar itself does not move for a cluster. A member that cannot carry its own citation is
dropped under the evidence bar like any other candidate — never carried along on its
neighbours' backing.

### The slate shows every site

A clustered candidate is one slate row, and that row names every site it covers with the
citation behind each. Collapsing five findings into one unexplained line takes back exactly
the visibility the negotiation exists to give: the user cannot strike a site they cannot
see, and a five-site defect and a one-site defect print identically.

They may split a row apart, drop a site from it, or merge two rows kept separate. All three
are theirs. Clustering exists to stop the sweep proposing five tickets for one defect, not
to settle the count before the user sees it.

### When a cluster cannot become one ticket

Two things force members apart even though the root cause is shared:

- **Different milestones.** A ticket lives at `<bucket>/<milestone>/<category>/`, so members
  the slate assigns to different milestones have no single path to be written to.
- **A member whose fix genuinely differs.** It fails the one-Direction test, so it is not
  one ticket, however plainly it comes from the same cause.

Those stay separate tickets, and each carries the optional `cluster` front-matter key: a
kebab-case value naming the shared root cause, identical across every member. `sift-drain`
reads that key and re-assembles the members at dispatch time, so the relationship survives
the split without any ticket having to overstate its scope. The key's bounds and the
grouping rules are the convention's and the drain skill's to state — do not restate them
here, because two documents describing one algorithm is how they come to disagree.

So there are three outcomes, not two. One shared Direction is one ticket. A shared root
cause with different Directions is several tickets under one `cluster` value. A shared
symptom with nothing behind it is several unrelated tickets and no key at all.

### Five worked examples

These come from the backlog this skill was drafted against. The IDs mean nothing in another
repository — read them for where the line falls, not as convention.

- **One fix, two files: the model cluster.** Two tickets (SFT-0023, SFT-0028) each truncated
  a label at its first blank, one in a script and one in a cookbook recipe, and one sentence
  fixes both — strip the `uniq -c` count off the front of the line rather than reading the
  label as a field. Found in a single sweep, that is one ticket carrying two `file:line`
  citations. It is also the milestone case: those two sites were assigned to different
  milestones, and once that is decided the merge is off — they stay two tickets under one
  `cluster` value, rather than one ticket in a folder that contradicts its own front matter.
- **One fix, seven sites, correctly merged already.** SFT-0026 unified how seven
  front-matter fence parsers spelled their closing marker. One Direction — pick one spelling
  and use it in all seven places — and seven citations in one ticket. A sweep that returned
  seven findings there should have produced that ticket, not seven of them.
- **One root cause, several fixes: stays split.** Five tickets (SFT-0009, SFT-0012,
  SFT-0015, SFT-0025, SFT-0031) all came from reading a ticket ID as a substring instead of
  a whole token, and no single Direction covers them: one widened a regex repetition, one
  widened a schema facet, one anchored a `grep -E`, and the last needed the surrounding
  cell-selection loop changed rather than the pattern — which is precisely why the ticket
  before it left that site alone. Same cause, five Directions: five tickets, one `cluster`
  value.
- **Shared symptom, unrelated fixes: not a cluster at all.** Four tickets (SFT-0010,
  SFT-0013, SFT-0014, SFT-0021) all read as "a recipe reports a clean tree when it read
  nothing", and their fixes have nothing in common — an existence guard on the tree,
  neutralising `grep`'s empty-input status, a `[ -d "$m" ] || continue` inside a loop, and a
  test on a `find` result before the write that follows it. Merging on that symptom produces
  one ticket no single Direction can serve. The most they can ever be is separate tickets
  under one `cluster` value, and only if the cause really is one and not just the phrasing
  of the complaint.
- **Mostly one fix, one member that differs.** Two tickets (SFT-0024, SFT-0033) gave scripts
  an end-of-options `--` arm. Five of the six sites take the same Direction verbatim; the
  sixth takes it differently, because that script's first positional is a subcommand rather
  than an option, so `--` in front of it must not turn the subcommand into an unknown one.
  The five cluster into one ticket; the sixth is its own ticket carrying the same `cluster`
  value.

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
in this skill.** They spent the decision once and wrote the reason down; handing it back
as fresh work says the skill did not read what they wrote. Re-rejecting costs them more
than the proposal was ever worth, and once they have seen it happen they read the whole
slate as noise and stop running the skill. The `resolution` column exists to make that
impossible. Read it.

Match on subject matter, not on title strings. An archived ticket titled "Drop the
vendored parser" covers a candidate titled "Replace the bundled parser with the upstream
library"; the corpus is small enough to read every line of, so read every line of it.

## When the corpus and the sweep disagree

An open ticket whose evidence the sweep found has moved on — the cited line has changed,
the work is partly done — is not a candidate. It is an update to something that already
exists, and it goes to the user as a note beside the slate. This skill writes new tickets;
it does not rewrite existing ones, and quietly proposing a duplicate of live work is the
same trust failure as re-proposing archived work, with a split ID space thrown in.
