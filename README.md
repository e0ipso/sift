# sift — file-based ticketing

sift is this repository's ticket system. It is plain markdown files on disk, operated
with ordinary terminal tools (`find`, `grep`, `mv`, `sed`). There is no daemon, no
database, and no CLI to install. Agents and humans follow the same rules.

## Configuration

Two things are per-repository configuration rather than part of the convention: the
ticket **prefix** and the set of **milestones**.

The prefix lives in `.ai/sift/config/config.yaml`:

```yaml
prefix: ABCD      # uppercase; stable for the life of the repository
```

Every ticket ID is `<PREFIX>-<NNNN>`, and that file is the single place the value is
defined. Everything below writes `<PREFIX>` as a placeholder — substitute the configured
value when you read it, and write the substituted form in real tickets and filenames,
never the literal `<PREFIX>`. The cookbook commands read it into a `$PREFIX` shell
variable, so changing the declaration (and renaming existing files) is the whole
migration.

Milestones are named and ordered in `MILESTONES.md`. This file writes `<milestone>` as a
placeholder the same way; substitute a name from `MILESTONES.md` when you read it.

## Directory layout

```
.ai/sift/
├── .gitignore                 ← ignores the tree by default; delete it to track tickets
├── README.md                  ← this convention (read it before touching tickets)
├── MILESTONES.md              ← what each milestone means, in intended order
├── ROADMAP.md                 ← advisory resolution order (tickets' depends_on is the truth)
├── RUNLOG.md                  ← append-only drain run log; diagnostic, never ticket state
├── schemas/                   ← XSD drafting schemas (authoring aid; see "Drafting a ticket")
│   ├── sift-common.xsd
│   ├── bug-ticket.xsd
│   ├── feature-ticket.xsd
│   └── task-ticket.xsd
├── open/                      ← actionable work
│   └── <milestone>/           ← one of the milestones in MILESTONES.md
│       └── <category>/        ← bug | hardening | feature | test | docs | dx | release
│           └── <PREFIX>-0001--short-slug.md
└── archive/                   ← finished work (done, wontfix, superseded)
    └── <milestone>/<category>/<PREFIX>-0001--short-slug.md   (mirrors open/)
```

- **One file = one ticket.** Never put two problems in one file; file a second ticket
  and link it with `depends_on` or a `[[<PREFIX>-XXXX]]` mention in the body.
- **Two buckets only.** `open/` holds anything still actionable (including
  `in-progress` and `blocked`). `archive/` holds anything terminal. The bucket is the
  coarse lifecycle; the `status` front-matter key is the fine-grained truth.
- **The hierarchy below the bucket is `<milestone>/<category>/`.** Both values are
  duplicated in front-matter so `grep` works even when a file has been moved.
- **`RUNLOG.md` is written by the drain, never by hand.** The drain appends one row per
  ticket dispatch and per ticket return, and the file is created on the first dispatch —
  a freshly initialized tree has none. It is diagnostic timing only: it records nothing
  about a ticket that the ticket file does not already say, so never read ticket state
  out of it.
- **The tree is untracked by default.** The shipped `.gitignore` is `*` and
  `!.gitignore`, so the backlog stays local and git history stays free of ticket churn.
  Delete that file to track tickets instead; nothing else in the convention depends on
  the choice. Either way, remember that ignore-aware search tools (`rg`, editor and
  agent search) skip an ignored tree silently — the recipes below use `find` and `grep`
  directly for exactly that reason.

## File naming

`<PREFIX>-<NNNN>--<kebab-slug>.md`

- `<PREFIX>-<NNNN>` is the ticket ID: zero-padded, sequential, **immutable, never
  reused**, globally unique across both buckets. The prefix comes from the
  *Configuration* section above. The slug may be edited; the ID may not.
- Allocate the next ID as the highest existing one across **both** buckets plus one —
  never the highest existing ID itself, which is already taken (see cookbook below).

## Front-matter schema

Every ticket starts with YAML front-matter. Required keys are marked ✱.

```yaml
---
id: <PREFIX>-0042      # ✱ matches the filename prefix
title: Short imperative summary            # ✱
status: open           # ✱ open | in-progress | blocked | done | wontfix | superseded
type: bug              # ✱ bug | hardening | feature | test | docs | dx | release
milestone: <milestone> # ✱ from MILESTONES.md; must match the folder it lives in
priority: p2           # ✱ p1 critical | p2 high | p3 normal | p4 someday
effort: m              # ✱ s | m | l | xl (honest guess, revise freely)
created: 2026-08-05    # ✱ YYYY-MM-DD
updated: 2026-08-05    # ✱ bump on every meaningful edit
labels: [api, caching] # free-form kebab tags
depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]
resolution: ""         # required non-empty when archived: one line on how it ended
source: ""             # where the ticket came from (session, issue URL, review)
---
```

Statuses `open | in-progress | blocked` live in `open/`. Statuses
`done | wontfix | superseded` live in `archive/` and require a non-empty `resolution`.

## Ticket body

Every body is built from four canonical sections, in this order, omitting ones that are
genuinely empty:

```markdown
# <title, repeated>

## Problem
What is wrong or missing, and why it matters. 2–6 sentences.

## Evidence
File paths / line refs / test names / external links backing the claim.

## Direction
The proposed approach, alternatives considered, known constraints.

## Acceptance criteria
- [ ] Checkable statements that define "done".
```

Two types add sections to that skeleton, because the four alone let a drafter skip the
question that type most needs answered.

**`type: bug`** — a bug ticket that does not say what *should* happen is not actionable:

```markdown
## Problem
## Expected behaviour        ← required: what should happen instead
## Steps to reproduce        ← optional: numbered list, one step per line
## Evidence                  ← required for bugs: cite file:line
## Direction
## Acceptance criteria
```

**`type: feature`** — `Problem` carries the motivation and `Direction` the proposal, so
only the discarded options need a home of their own:

```markdown
## Problem                   ← the motivation: why this is needed, whose use case
## Evidence
## Direction                 ← the proposed solution
## Alternatives considered   ← optional: other approaches, and why they lose
## Acceptance criteria
```

**Every other type** (`hardening | test | docs | dx | release`) uses the four canonical
sections unchanged.

## Drafting a ticket

`schemas/` holds one XSD per body shape. They exist because a drafter writing markdown
straight into the file skips the awkward field — the expected behaviour it has not pinned
down, the alternative it did not weigh — and the omission is invisible afterwards. Filling
a structure that names every field forces the gap to surface while it can still be closed.

Draft into a scratch file outside `.ai/sift/`, then render it to the markdown ticket and
throw the draft away:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bug-ticket xmlns="urn:sift:ticket:v1">
  <front-matter>
    <id>ABCD-0042</id>
    <title>Fix cache key collision on tenant switch</title>
    <status>open</status>
    <type>bug</type>
    <milestone>foundations</milestone>
    <priority>p2</priority>
    <effort>m</effort>
    <created>2026-08-07</created>
    <updated>2026-08-07</updated>
    <labels><label>api</label><label>caching</label></labels>
    <depends-on><ticket>ABCD-0041</ticket></depends-on>
  </front-matter>
  <problem>The cache key omits the tenant id, so tenant B reads tenant A's payload.</problem>
  <expected-behaviour>Each tenant resolves its own payload.</expected-behaviour>
  <steps-to-reproduce>
    <step>Warm the cache as tenant A.</step>
    <step>Request the same route as tenant B.</step>
  </steps-to-reproduce>
  <evidence><item>src/cache/key.ts:31 builds the key from route alone.</item></evidence>
  <direction>Prefix the key with the resolved tenant id.</direction>
  <acceptance-criteria>
    <criterion>Cross-tenant read returns tenant B's payload.</criterion>
  </acceptance-criteria>
</bug-ticket>
```

| Draft element | Renders to |
|---|---|
| `<front-matter>` children | the YAML keys of the same name (`<depends-on>` → `depends_on`) |
| `<labels>`, `<depends-on>` | YAML flow lists — `labels: [api, caching]` |
| `<problem>` / `<motivation>` / `<description>` | `## Problem` |
| `<expected-behaviour>` | `## Expected behaviour` |
| `<steps-to-reproduce><step>` | `## Steps to reproduce`, numbered list |
| `<evidence><item>` | `## Evidence`, one bullet per item |
| `<direction>` / `<proposed-solution>` | `## Direction` |
| `<alternatives-considered>` | `## Alternatives considered` |
| `<acceptance-criteria><criterion>` | `## Acceptance criteria`, one `- [ ]` per criterion |

Which root element to use: `<bug-ticket>` for `type: bug`, `<feature-ticket>` for
`type: feature`, `<task-ticket>` for the other five types.

**The XML is scaffolding, not storage, and no tool is required to use it.** The ticket on
disk is markdown with YAML front-matter, exactly as specified above; nothing in sift reads,
writes, or validates XML on the way in or out. Read `schemas/*.xsd` as a checklist and
render by hand — that is the supported path, and it works on a machine with nothing but a
text editor. If `xmllint` happens to be installed, the optional recipe in the cookbook will
also machine-check a draft; if it is not installed, skip it and lose nothing but a
convenience. Never make a ticket, a recipe, or a workflow depend on it.

Two rules the schemas cannot carry, because XSD 1.0 has no cross-field assertions:
a non-empty `resolution` is required once `status` is terminal, and `milestone` must name a
milestone from `MILESTONES.md` that matches the ticket's folder. Check both by hand.

## Mapping to a remote tracker

When a ticket mirrors an issue on GitHub, GitLab or Gitea, record the issue URL in
`source:` and translate the dimensions below. Sift keeps them as separate front-matter keys
rather than as label strings — a tracker with one flat label field has to encode scope in
the label name (`priority::major`), which sift does not need and must not duplicate. **A
fact stored in both a front-matter key and a label has two sources of truth and will drift;
front-matter wins.**

| Sift front-matter | Scoped label on the tracker |
|---|---|
| `type: bug` | `category::bug` |
| `type: feature` | `category::feature` |
| `type: hardening \| test \| docs \| dx \| release` | `category::task` |
| `priority: p1 \| p2 \| p3 \| p4` | `priority::critical \| major \| normal \| minor` |
| `status:` | `state::*` — sift's statuses are the authority; a tracker state with no sift equivalent is dropped |
| `resolution:` on an archived ticket | `why::*` plus the closing comment |
| `labels:` | plain topic labels, unscoped |

`labels:` stays free-form kebab-case precisely because the scoped dimensions already have
keys. Use it for topic tags (`api`, `caching`, `onboarding`), never to restate `type`,
`priority` or `status`.

## Rules for agents

1. **Read this file before creating or moving tickets.** Follow it exactly.
2. **Never renumber, reuse, or delete a ticket ID.** Wrong ticket? Archive it with
   `status: wontfix` and a `resolution`. Files are deleted only by the human owner.
3. **Front-matter is the source of truth**; folders are an index. When you `mv` a
   ticket, update `milestone`/`status` front-matter in the same change, and vice versa.
4. **Archiving = edit + mv.** Set `status`, `resolution`, `updated`, then `mv` the file
   to the mirrored path under `archive/` (`mkdir -p` the target first).
5. **Keep tickets atomic and evidence-based.** Claims about code cite `file:line`.
6. **Bump `updated`** whenever you change anything meaningful.
7. Cross-reference tickets inline as `<PREFIX>-XXXX` — plain text, greppable.
8. New milestone or category folders are allowed, but document new milestones in
   `MILESTONES.md` in the same change. Categories are a closed set; propose additions
   by editing this README.
9. **Keep `ROADMAP.md` in sync — in the same change.** When you create a ticket, slot
   it into the appropriate wave (respecting its `depends_on`; add a new wave row, don't
   renumber existing ones). When you archive a ticket (done/wontfix/superseded), mark
   its roadmap row with `~~strikethrough~~` and the resolution status rather than
   deleting it. When you change a ticket's `depends_on` or move it between milestones,
   re-check its wave placement. Then run the roadmap consistency check below — a
   ticket missing from the roadmap, or a roadmap entry pointing at nothing, is a
   convention violation.
10. **Use the body template for the ticket's `type`.** A `bug` states its expected
    behaviour and cites `file:line`; a `feature` states its motivation. Draft against
    `schemas/` when writing a new ticket — but never make anything depend on `xmllint`
    being installed.

## Operations cookbook (terminal)

All commands assume you run them from the repository root
(`.ai/sift/...` paths) — adjust if elsewhere.

**Set the prefix once per shell.** Every recipe below reads `$PREFIX`; export it first
and nothing else needs editing when the prefix changes. The tree guard on the next
line fails closed when `.ai/sift` is missing, so a validation recipe run from the
wrong directory cannot report a clean bill of health for a tree it never read:
```sh
export PREFIX=$(grep -m1 '^prefix:' .ai/sift/config/config.yaml | awk '{print $2}' | tr -d "\"'")
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; exit 1; }
```

Recipes that name one milestone read `$MILESTONE`; set it to a name from
`MILESTONES.md` when you need them:
```sh
export MILESTONE=$(basename "$(find .ai/sift/open -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)")
```

**List every open ticket:**
```sh
find .ai/sift/open -name "$PREFIX-*.md" | sort
```

**Allocate the next ID** (highest existing + 1, across both buckets; prints
`<PREFIX>-0001` on an empty tree):
```sh
[ -d .ai/sift ] && find .ai/sift -name "$PREFIX-*.md" | awk -v prefix="$PREFIX" '
  BEGIN { max = 0 }
  {
    name = $0
    sub(/^.*\//, "", name)
    if (index(name, prefix "-") != 1) next
    rest = substr(name, length(prefix) + 2)
    if (match(rest, /^[0-9]+/) == 0) next
    n = substr(rest, 1, RLENGTH) + 0
    if (n > max) max = n
  }
  END { printf "%s-%04d\n", prefix, max + 1 }
'
```
Numeric comparison, not lexical sort, is what makes this correct once the tree passes
`<PREFIX>-9999`: `%04d` is a *minimum* width, so the successor of `<PREFIX>-9999` is
`<PREFIX>-10000` rather than a truncated four-digit collision. The inline
`[ -d .ai/sift ]` guard matters here even when the shared tree guard above already
ran: `awk`'s `END` block fires even when `find` printed nothing, so a copied
allocation one-liner run from the wrong directory would otherwise report
`<PREFIX>-0001` — an ID that is already taken — instead of failing.

**Triage view — id, title, priority for one milestone:**
```sh
grep -r --include="$PREFIX-*.md" -H '^title:' ".ai/sift/open/$MILESTONE" | sort
grep -rl '^priority: p1' .ai/sift/open        # all critical tickets
```

**Count open tickets per milestone:**
```sh
for m in .ai/sift/open/*/; do
  [ -d "$m" ] || continue
  printf '%-28s %s\n' "$(basename "$m")" "$(find "$m" -name "$PREFIX-*.md" | wc -l)"
done
```
The `[ -d "$m" ] || continue` guard is what keeps an `open/` with no milestone folder
silent. A glob that matches nothing is passed through *literally* by every POSIX shell,
so without the guard the loop runs once for the string `.ai/sift/open/*/`, invents a
milestone named `*` with a count of `0`, and leaves `find` complaining on stderr. The
test is `-d`, not `nullglob`: `shopt` is a bash builtin, and these recipes are meant to
survive being pasted into `dash` or any other POSIX shell. A milestone folder that
exists but holds no ticket is a real answer and still reports `0`.

**Find a ticket wherever it lives:**
```sh
find .ai/sift -name "$PREFIX-0042--*.md"
```
The `--` is what makes this one ticket rather than a family: a bare `$PREFIX-0042*` glob
also matches `$PREFIX-00420--*.md` and every longer ID sharing those leading digits, which
is a live case once a tree passes `<PREFIX>-9999`.

**Full-text search (e.g. every ticket touching one symbol or subsystem):**
```sh
grep -ril 'cache invalidation' .ai/sift --include="$PREFIX-*.md"
```

**List every label in use** (sorted, unique kebab tags from `labels:` front-matter):
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f"
done | sort -u
```

**Count tickets per label:**
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f"
done | sort | uniq -c | awk '{ printf "%s\t%s\n", $2, $1 }' | sort -k1,1
```

**List tickets carrying one label** (`$LABEL` is kebab-case, e.g. `caching`):
```sh
LABEL=caching
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk -v want="$LABEL" '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] == want) { print FILENAME; exit }
      }
      exit
    }
  ' "$f"
done | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^id:/    { id = $2; next }
    infm && /^title:/ { title = $0; sub(/^title:[[:space:]]*/, "", title); next }
    END { printf "%s  %s  %s\n", id, title, FILENAME }
  ' "$f"
done
```
The display line walks the same fence as the filter above it rather than reaching for
`grep -m1 '^id:'`. `-m1` is not a scope: it stops at the first match *anywhere* in the
file, so a ticket whose front matter omits `title:` renders whatever body sentence quotes
the key at column 0 — and a repository that documents this convention writes such
sentences for a living. Reading both keys in one `awk` pass also replaces four processes
per file with one.

**Who depends on `$PREFIX-0042`:**
```sh
grep -rlE "$PREFIX-0042([^0-9]|$)" .ai/sift --include="$PREFIX-*.md" | grep -v "$PREFIX-0042--"
```
`([^0-9]|$)` is the whole-ID anchor, and it is the difference between an answer and a
guess: a bare substring search reports `$PREFIX-00420` and every longer ID as a dependent
of `$PREFIX-0042`, purely because each such ticket carries its own ID in its front matter.
Since `depends_on` — not `ROADMAP.md` — decides whether a ticket is safe to start or
archive, a phantom dependent inverts that call. The trailing `grep -v` still drops the
target's own file, which legitimately matches its own ID.

**Pick the next thing to work on** (open, p1, not blocked):
```sh
grep -rl '^priority: p1' .ai/sift/open --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^status: blocked' "$f" || echo "$f"; done | sort
```

**In-place edits use a temp file, never `sed -i`.** The flag is not POSIX and the two
implementations disagree: GNU `sed -i` takes an optional suffix attached to the flag, BSD
(macOS) `sed -i` *requires* a separate suffix argument, so `sed -i 's/a/b/' file` silently
consumes the script as the suffix there and mangles the tree. Write `sed … "$f" > "$f.tmp"
&& mv "$f.tmp" "$f"` instead — portable, and the `.tmp` name cannot match the
`$PREFIX-*.md` glob, so a concurrent agent's `find` never sees the half-written file.

**Move a ticket to another milestone** (edit `milestone:` key too):
```sh
DEST=<target-milestone>                              # a name from MILESTONES.md
f=$(find .ai/sift/open -name "$PREFIX-0042--*.md")
d=".ai/sift/open/$DEST/$(basename "$(dirname "$f")")"   # keep the same category
mkdir -p "$d" && mv "$f" "$d/"
t="$d/$(basename "$f")"
DEST="$DEST" awk '
  BEGIN { in_fm = 0; wrote = 0 }
  NR == 1 && /^---$/ { in_fm = 1; print; next }   # front matter starts at line 1 only
  in_fm && /^---$/ { in_fm = 0; print; next }     # …and ends at the first closing fence
  in_fm && /^milestone:/ {
    print "milestone: " ENVIRON["DEST"]
    wrote = 1
    next
  }
  { print }
  END {
    if (!wrote) {
      print "move: no milestone: key in the front matter" > "/dev/stderr"
      exit 1
    }
  }
' "$t" > "$t.tmp" && mv "$t.tmp" "$t" || {
  rm -f "$t.tmp"
  echo "MILESTONE NOT UPDATED in $t: the file moved, set the key by hand" >&2
  false
}
```
The rewrite is confined to the leading front-matter block, so a body line that quotes
`milestone:` at column 0 — which a ticket discussing this convention will — survives
byte-for-byte, and a `---` horizontal rule further down cannot re-open the region. `awk`
string concatenation puts `$DEST` in place rather than a `sed` replacement text, for the
same reason `resolution:` uses it below: a replacement is re-scanned for `&` and `\1`.
A ticket whose front matter carries no `milestone:` key stops loudly with the file already
moved, because a move that silently leaves the key behind is the desync rule 2 forbids.

**Archive a finished ticket** — the front-matter edit, the `mv` and the `ROADMAP.md`
strike rule 9 requires are one workflow, so run all three together:
```sh
ID=$PREFIX-0042
STATUS=done                                    # done | wontfix | superseded
RESOLUTION='Fixed in commit abc1234'           # required non-empty
f=$(find .ai/sift/open -name "$ID--*.md")
[ -n "$RESOLUTION" ] || { echo "archive: RESOLUTION must be non-empty" >&2; false; }
RESOLUTION="$RESOLUTION" STATUS="$STATUS" TODAY="$(date +%F)" awk '
  BEGIN { in_fm = 0; wrote = 0 }
  function emit_res(   v) {
    v = ENVIRON["RESOLUTION"]
    if (v == "") {
      print "archive: RESOLUTION must be non-empty" > "/dev/stderr"
      exit 1
    }
    print "resolution: \"" v "\""
    wrote = 1
  }
  NR == 1 && /^---$/ { in_fm = 1; print; next }   # front matter starts at line 1 only
  in_fm && /^---$/ {                              # …and ends at the first closing fence
    if (!wrote) emit_res()                  # insert before closing fence when absent
    in_fm = 0
    print
    next
  }
  in_fm && /^status:/  { print "status: "  ENVIRON["STATUS"]; next }
  in_fm && /^updated:/ { print "updated: " ENVIRON["TODAY"];  next }
  in_fm && /^resolution:[[:space:]]*/ {      # rewrite existing (incl. empty) line
    emit_res()
    next
  }
  { print }
  END {
    if (!wrote) {
      print "archive: no front-matter found to hold resolution" > "/dev/stderr"
      exit 1
    }
  }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; false; }
dest=$(printf '%s\n' "$f" | sed 's#/open/#/archive/#')
mkdir -p "$(dirname "$dest")" && mv "$f" "$dest"

R=.ai/sift/ROADMAP.md
awk -v id="$ID" -v prefix="$PREFIX" -v st="$STATUS" '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  function tail_bs(s,   k) {              # trailing backslashes; odd = escaped pipe
    k = 0
    while (k < length(s) && substr(s, length(s) - k, 1) == "\\") k++
    return k % 2
  }
  function cut(s, a,   t, n, i, m) {      # split a table row on UNESCAPED pipes only
    n = split(s, t, "|"); m = 0
    for (i = 1; i <= n; i++)
      if (m > 0 && tail_bs(a[m])) a[m] = a[m] "|" t[i]; else a[++m] = t[i]
    return m
  }
  BEGIN { pat = prefix "-[0-9][0-9][0-9][0-9][0-9]*" }
  {
    line[NR] = $0; last = NR
    if ($0 !~ /^[[:space:]]*\|/) next       # table rows only
    m = cut($0, c); if (m < 3) next
    k = 0                                   # first ID-bearing cell IS the ticket cell
    for (i = 1; i <= m; i++) { b = c[i]; gsub(/~~/, "", b); if (b ~ pat) { k = i; break } }
    if (k == 0) next
    b = c[k]; gsub(/~~/, "", b); match(b, pat)
    if (substr(b, RSTART, RLENGTH) != id) next
    hits++; hl = NR; hk = k
  }
  END {
    if (hits + 0 != 1) {                    # missing or ambiguous: write nothing
      printf "roadmap: %d rows for %s, expected exactly 1\n", hits + 0, id > "/dev/stderr"
      exit 1
    }
    m = cut(line[hl], c)
    if (c[hk] ~ /~~/ || (hk + 1 < m && c[hk + 1] ~ /~~/)) {
      printf "roadmap: %s is already struck, left as is\n", id > "/dev/stderr"
    } else {
      c[hk] = " ~~" trim(c[hk]) "~~ "
      if (hk + 1 < m) {
        t2 = trim(c[hk + 1])
        c[hk + 1] = (t2 == "" ? " " : " ~~" t2 "~~ ") "— " st " "
      }
      out = c[1]
      for (i = 2; i <= m; i++) out = out "|" c[i]
      line[hl] = out
    }
    for (i = 1; i <= last; i++) print line[i]
  }
' "$R" > "$R.tmp" && mv "$R.tmp" "$R" || {
  rm -f "$R.tmp"
  echo "ROADMAP NOT UPDATED for $ID: strike its row by hand before committing" >&2
  false
}
```
`$RESOLUTION` is required and checked before any rewrite: an empty value prints
`archive: RESOLUTION must be non-empty` and exits non-zero with the ticket untouched.
All three keys are rewritten by one `awk` pass, and every rule in it is guarded by
`in_fm`. That scoping is the point: a line-anchored `sed 's/^status: .*/…/'` also matches
the body, so a ticket whose `## Direction` opens a line with `status:` — routine in a
repository that documents this convention — has that sentence silently replaced by a
front-matter line, visible only in `git diff`, at the moment an operator stops reading the
ticket. `in_fm` is set only by a `---` on line 1 and cleared by the first closing fence, so
a `---` horizontal rule in the body cannot re-open the region either. Values come from
`ENVIRON` and are concatenated rather than substituted, so `&`, `/`, `|` and `[` survive
byte-for-byte — a `sed` replacement text would re-scan them. `status:` and `updated:` are
rewritten where they already sit, exactly once each; `resolution:` is insert-or-replace,
rewriting an existing line (including `resolution: ""`) or inserting exactly one line
before the closing `---` when the key is absent, so a second run never duplicates it. A
ticket with no front-matter fence fails loudly, with the file untouched, rather than
archiving without the required field.

The strike keys off the immutable `$ID`, never the title or the slug, and it rewrites
through `$R.tmp` plus `mv` so an interrupted run can never leave a half-written roadmap.
`awk` string concatenation does the editing rather than a `sed` substitution, because a
replacement text is re-scanned for `&` and `\1` — a title like `tenant caching & sharding`
would come back mangled. Two rules keep the match honest. Only the *first* ID-bearing cell
of a row is the ticket cell, so `$PREFIX-0042` appearing in another row's `Needs` column is
never mistaken for that row's ticket; and the ID must match the cell in full, so
`$PREFIX-0042` does not strike `$PREFIX-00420`. Anything other than exactly one matching
row — none, or the same ID slotted into two waves — prints the count and exits non-zero
with the roadmap untouched and no `.tmp` left behind, because a rule 9 desync that reports
success is worse than one that stops you. Re-running on an already-struck row is a no-op,
not a double strike.

**Roadmap consistency check** (run after creating, archiving, or re-wiring tickets).
The shared tree guard from the prefix setup is restated so a copied block still fails
closed when `.ai/sift` is missing; a consistent tree stays silent:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; exit 1; }
# Every ticket (open or archived) must appear in ROADMAP.md ...
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]+" | sort -u | while read -r id; do
    grep -qE "$id([^0-9]|$)" .ai/sift/ROADMAP.md || echo "NOT IN ROADMAP: $id"
  done
# ... and every roadmap ID must correspond to a ticket file somewhere.
grep -oE "$PREFIX-[0-9]+" .ai/sift/ROADMAP.md | sort -u | while read -r id; do
  find .ai/sift/open .ai/sift/archive -name "$id--*.md" | grep -q . || echo "STALE IN ROADMAP: $id"
done
```
Extraction matches the whole numeric suffix (`[0-9]+`), not a fixed four digits, so an ID
that has grown past `<PREFIX>-9999` is captured whole rather than truncated. Four digits
remain the *rendering* width when allocating a new ID (`%04d` above); these recipes only
read IDs back. Both directions compare whole IDs for the same reason: the forward lookup
anchors with `([^0-9]|$)` and the reverse one with `$id--`, so a row for `<PREFIX>-00420`
never vouches for a missing `<PREFIX>-0042`.

**Validate front-matter across the tree** (files missing a required key). Same tree
guard as above; when every required key is present the loop prints only the section
headers and exits 0 — including on a tree that holds no tickets at all:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; exit 1; }
for k in id title status type milestone priority effort created updated; do
  echo "== missing $k:"
  grep -rL "^$k:" .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md" || [ $? -eq 1 ]
done
```
`|| [ $? -eq 1 ]` neutralises one status and only one: grep's "nothing was selected",
which is the answer a tree with no ticket files gives — both GNU and BSD `grep` exit 1
when the search matched nothing, and the loop's last command decides the block's status.
Without it a freshly initialised tree reports failure for being empty, and under `set -e`
the run stops after the first of the nine headers. A genuine `grep` failure — status 2,
which is what a missing or unreadable `.ai/sift/archive` produces — is *not* absorbed, so
the block can never print nine clean headers for a tree it only half read. A blanket
`|| true` would absorb that too, and the tree guard above exists precisely to stop this
recipe reporting clean on a tree it did not read.

**Find bug tickets missing the `## Expected behaviour` section** (the backfill list after
adopting the type-specific templates — add the section to each, or accept it as debt):
```sh
grep -rl '^type: bug' .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^## Expected behaviour' "$f" || echo "$f"; done
```

**Find feature tickets whose Direction is missing** (`## Direction` carries the proposal):
```sh
grep -rl '^type: feature' .ai/sift/open --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^## Direction' "$f" || echo "$f"; done
```

**Machine-check a draft — optional, only if `xmllint` is already installed.** Nothing in
this convention requires it: the schemas are a checklist you can read, and a ticket
rendered by hand without ever running this is fully valid. The guard below makes the
recipe a no-op rather than a failure on a machine without the binary:
```sh
if command -v xmllint >/dev/null; then
  xmllint --noout --schema .ai/sift/schemas/bug-ticket.xsd /tmp/draft.xml
else
  echo "xmllint not installed — skipping (optional); check the schema by eye"
fi
```

**Sanity-check folder/front-matter agreement:**
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | while read -r f; do
  m=$(awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^milestone:/ { print $2; exit }
  ' "$f")
  if [ -z "$m" ]; then
    echo "NO MILESTONE: $f"
  else
    case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
  fi
done
```
The milestone is read by walking the leading `---` fence, the same way the label recipes
and the move/archive rewrites do. `grep -m1 '^milestone:'` searched the whole file, and it
failed on precisely the ticket this check exists to catch: front matter with no
`milestone:` key at all, whose first match is then a body line quoting the key at column 0.
The folder got compared against a sentence, and a ticket missing a required key was
reported as clean.

The two findings are kept apart because they are different repairs. `MISMATCH:` means the
front matter is authoritative and the file is in the wrong directory — fix it with the
milestone move above. `NO MILESTONE:` means there is nothing to compare against: the key is
absent, or present with an empty value, so the front-matter validation and the move recipe
will both fail on this ticket too, and the fix is to write the key. Folding the second into
the first would report a ticket as filed under the wrong milestone when it claims no
milestone at all.
