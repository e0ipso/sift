# sift — file-based ticketing

sift stores tickets as markdown files. Agents and humans operate the same tree with
ordinary terminal tools. There is no daemon, database, or CLI to install.

## Configuration

Each repository configures its ticket **prefix** and **milestones**.

The prefix lives in `.ai/sift/config/config.yaml`:

```yaml
prefix: ABCD      # uppercase; stable for the life of the repository
```

Every ticket ID is `<PREFIX>-<NNNN>`. `config.yaml` is the single source for the prefix;
`MILESTONES.md` names and orders milestones.

`<PREFIX>` and `<milestone>` below are placeholders. Real tickets and filenames use the
configured values. Cookbook commands read the prefix into `$PREFIX`. Changing a prefix
requires changing `config.yaml` and renaming every existing ticket file and ID.

## Directory layout

```
.ai/sift/
├── .gitignore                 ← ignores the tree by default; delete it to track tickets
├── README.md                  ← this convention (read it before touching tickets)
├── MILESTONES.md              ← what each milestone means, in intended order
├── ROADMAP.md                 ← advisory resolution order (tickets' depends_on is the truth)
├── RUNLOG.md                  ← append-only drain run log; diagnostic, never ticket state
├── config/                    ← per-repository configuration (see "Configuration" above)
│   └── config.yaml            ← the ticket prefix; the single place the value is defined
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

- **One file = one ticket.** Split separate problems and link them with `depends_on` or a
  `[[<PREFIX>-XXXX]]` body mention.
- **Two buckets only.** `open/` holds anything still actionable (including
  `in-progress` and `blocked`). `archive/` holds anything terminal. The bucket is the
  coarse lifecycle; the `status` front-matter key is the fine-grained truth.
- **The hierarchy below the bucket is `<milestone>/<category>/`.** Both values are
  duplicated in front-matter so `grep` works even when a file has been moved.
- **`RUNLOG.md` is drain-written, append-only diagnostic data.** A fresh tree has none. Do
  not write it by hand or read ticket state from it. See *Run log* for its schema.
- **The tree is untracked by default.** The shipped `.gitignore` contains `*` and
  `!.gitignore`; delete it to track tickets. Ignore-aware search tools skip the default
  tree, so the recipes use `find` and `grep` directly.

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
cluster: whole-token-ids  # optional kebab name of a root cause shared with other tickets
depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]
resolution: ""         # required non-empty when archived: one line on how it ended
source: ""             # where the ticket came from (session, issue URL, review)
---
```

Statuses `open | in-progress | blocked` live in `open/`. Statuses
`done | wontfix | superseded` live in `archive/` and require a non-empty `resolution`.

## Dispatch groups and the cluster key

`cluster` is an optional kebab-case value naming a shared root cause. It uses lowercase
letters and digits with single internal hyphens, like `labels:`. The drain may use it as a
relatedness hint when building a worker graph. It never authorizes work, reorders a wave,
changes ticket state, or causes a run to fail. An absent or malformed value provides no hint.

### Two bars, and which is which

Use two separate tests:

- Merge findings into one ticket only when one `## Direction` applies unchanged at every
  site. Otherwise, keep separate tickets.
- Give separate tickets the same `cluster` when they share a root cause and one worker can
  orient to them together, even if their fixes differ.

Each clustered ticket keeps its own `## Direction`, archive operation, and roadmap strike.
Tickets that touch the same product files run sequentially whether or not they share a
`cluster`.

### The bounds a helper group is formed under

`next-ticket.sh --group` is a helper, not the drain loop. It picks the lead by roadmap wave
and row order, then walks forward through dispatchable tickets with the lead's `cluster`.
It excludes struck rows, archived tickets, and `status: blocked`; `cluster` never reorders a
wave.

A group holds **at most 4 tickets** and **at most 8 combined effort weight**:

| effort | xs | s | m | l | xl |
|---|---|---|---|---|---|
| weight | 1 | 2 | 3 | 5 | 8 |

The schema allows `s | m | l | xl`. The helper also assigns `xs` weight 1 and defaults an
absent or unrecognized effort to `m` weight 3. The first ticket that would exceed either
bound ends the group; it is not skipped. The group also ends at the first unstruck
non-member, so it cannot cross a wave boundary.

## Ticket body

Every body is built from four canonical sections in this order. Omit only empty sections:

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

Two types add sections. **`type: bug`** — a bug ticket that does not say what *should*
happen is not actionable:

```markdown
## Problem
## Expected behaviour        ← required: what should happen instead
## Steps to reproduce        ← optional: numbered list, one step per line
## Evidence                  ← required for bugs: cite file:line
## Direction
## Acceptance criteria
```

**`type: feature`** — `Problem` carries the motivation and `Direction` the proposal:

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

`schemas/` holds one XSD per body shape. Use it as a field checklist.
Draft into a scratch file outside `.ai/sift/`, render the markdown ticket, then delete it:

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
    <wave>1</wave>
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

Use `<bug-ticket>` for `type: bug`, `<feature-ticket>` for `type: feature`, and
`<task-ticket>` for the other five types. XML is drafting scaffolding, never storage. Sift
reads and writes only markdown with YAML front-matter. Render by hand; `xmllint` is optional
and no workflow may require it.

XSD 1.0 cannot assert two cross-field rules. Check them by hand: terminal tickets require a
non-empty `resolution`, and `milestone` must match both `MILESTONES.md` and the ticket folder.

## Mapping to a remote tracker

For a mirrored GitHub, GitLab, or Gitea issue, put its URL in `source:` and use this mapping.
Do not duplicate scoped front-matter values as Sift labels. Front-matter is authoritative.

| Sift front-matter | Scoped label on the tracker |
|---|---|
| `type: bug` | `category::bug` |
| `type: feature` | `category::feature` |
| `type: hardening \| test \| docs \| dx \| release` | `category::task` |
| `priority: p1 \| p2 \| p3 \| p4` | `priority::critical \| major \| normal \| minor` |
| `status:` | `state::*` — sift's statuses are the authority; a tracker state with no sift equivalent is dropped |
| `resolution:` on an archived ticket | `why::*` plus the closing comment |
| `labels:` | plain topic labels, unscoped |

Use free-form kebab-case `labels:` for topics such as `api` or `caching`, never for `type`,
`priority`, or `status`.

## Run log

`sift-drain` creates `RUNLOG.md` on first dispatch and only appends after that. Never write
it by hand or use it as ticket state. It records dispatch groups. Six columns, and a literal
`-` in every cell an event has no use for:

```markdown
# Run log

Append-only. One row per drain event; rows are never rewritten.

| event | ticket | phase | utc | epoch | status |
|---|---|---|---|---|---|
| dispatch | <PREFIX>-0025 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| dispatch | <PREFIX>-0031 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| phase | - | orient | 2026-08-10T09:15:41Z | 1786353341 | - |
| phase | - | implement | 2026-08-10T09:22:10Z | 1786353730 | - |
| phase | - | verify | 2026-08-10T09:34:57Z | 1786354497 | - |
| phase | - | bookkeep | 2026-08-10T09:39:02Z | 1786354742 | - |
| return | <PREFIX>-0025 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
| return | <PREFIX>-0031 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
```

- `dispatch`: one row per ticket. All rows from one command share a `utc`/`epoch` pair.
- `phase`: one ticketless row for `orient`, `implement`, `verify`, or `bookkeep`.
- `return`: one row per ticket with its final status. All rows from one command share a
  `utc`/`epoch` pair.

Rows with the same dispatch epoch form one group. Readers calculate with the epoch integer
and never parse `utc`. Writers use `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s`, which work
across GNU and BSD systems.

## Rules for agents

1. **Read this file before creating or moving tickets.** Follow it exactly.
2. **Never renumber, reuse, or delete a ticket ID.** Wrong ticket? Archive it with
   `status: wontfix` and a `resolution`. Files are deleted only by the human owner.
3. **Front-matter is the source of truth**; folders are an index. When you `mv` a
   ticket, update `milestone`/`status` front-matter in the same change, and vice versa.
4. **Archiving = edit + mv.** Set `status`, `resolution`, `updated`, then `mv` the file
   to the mirrored path under `archive/` (`mkdir -p` the target first).
5. **One problem per ticket, and evidence-based.** Claims about code cite `file:line`.
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

Run these commands from the repository root.

**Run the writing recipes under `set -e`.** Their guards use `false` so pasted commands do
not close the caller's shell. Without `set -e`, `false` reports the error but later commands
still run. Use a subshell:
```sh
( set -e
  <paste the recipe here>
)
```
`bash -e block.sh` also works. Do not use `bash -e -c '…'`; the recipes contain single-quoted
`awk` programs. Recipes without guards do not need the wrapper.

**Set the prefix once per shell.** Every recipe reads `$PREFIX`. The tree guard prevents a
wrong-directory run from reporting success without reading a Sift tree:
```sh
export PREFIX=$(grep -m1 '^prefix:' .ai/sift/config/config.yaml | awk '{print $2}' | tr -d "\"'")
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
```

Recipes that name one milestone read `$MILESTONE`; set it from `MILESTONES.md`:
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
The recipe compares numbers. `%04d` is a minimum width, so 9999 advances to 10000. Its
inline tree guard suppresses all output outside a Sift tree; without it, `awk`'s `END` would
print `<PREFIX>-0001` after a failed `find`.

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
The `-d` guard keeps an empty `open/` silent because an unmatched POSIX glob remains literal.
Do not replace it with bash-only `nullglob`.

**Find a ticket wherever it lives:**
```sh
find .ai/sift -name "$PREFIX-0042--*.md"
```
The `--` boundary prevents `$PREFIX-0042` from matching longer IDs such as
`$PREFIX-00420`.

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
  ' "$f" | sort -u
done | sort | uniq -c |
  awk '{ n = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); printf "%s\t%s\n", $0, n }'
```
The inner `sort -u` counts tickets, not duplicate mentions. The final `awk` removes
`uniq -c`'s padded numeric prefix without truncating the label.

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
Both passes stop at the closing front-matter fence, so body lines that quote `id:` or
`title:` cannot supply missing metadata.

**Who depends on `$PREFIX-0042`:**
```sh
grep -rlE "$PREFIX-0042([^0-9]|$)" .ai/sift --include="$PREFIX-*.md" | grep -v "$PREFIX-0042--"
```
`([^0-9]|$)` matches the whole numeric ID rather than longer IDs with the same prefix. The
trailing `grep -v` removes the target ticket itself.

**Pick the next thing to work on** (open, p1, not blocked):
```sh
grep -rl '^priority: p1' .ai/sift/open --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^status: blocked' "$f" || echo "$f"; done | sort
```

**In-place edits use a temp file, never `sed -i`.** GNU and BSD disagree on that flag. Use
`sed … "$f" > "$f.tmp" && mv "$f.tmp" "$f"`; this is portable, atomic at publication, and
keeps partial files outside the `$PREFIX-*.md` glob.

**Move a ticket to another milestone** (edit `milestone:` key too):
```sh
DEST=<target-milestone>                              # a name from MILESTONES.md
ID=$PREFIX-0042
f=$(find .ai/sift/open -name "$ID--*.md")
[ -n "$f" ] || { echo "move: no ticket matching $ID" >&2; false; }
[ -f "$f" ] || { echo "move: $ID does not match exactly one ticket" >&2; false; }
d=".ai/sift/open/$DEST/$(basename "$(dirname "$f")")"   # keep the same category
mkdir -p "$d" && mv "$f" "$d/"
t="$d/$(basename "$f")"
DEST="$DEST" awk '
  BEGIN { in_fm = 0; wrote = 0 }
  NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }  # front matter starts at line 1 only
  in_fm && /^---[[:space:]]*$/ { in_fm = 0; print; next }    # …and ends at the first closing fence
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
The rewrite changes `milestone:` only inside the leading front-matter fence. Both fence
patterns accept trailing space. `ENVIRON` and string concatenation preserve every byte of
`$DEST`, including `&` and backslashes.

Both guards precede `mkdir -p`, so a missing or ambiguous ID leaves the tree unchanged. If
front-matter has no `milestone:` key, the command stops after the file move and tells the
operator to repair the key by hand.

**Archive a finished ticket** — the front-matter edit, the `mv` and the `ROADMAP.md`
strike rule 9 requires are one workflow, so run all three together:
```sh
ID=$PREFIX-0042
STATUS=done                                    # done | wontfix | superseded
RESOLUTION='Fixed in commit abc1234'           # required non-empty
f=$(find .ai/sift/open -name "$ID--*.md")
[ -n "$f" ] || { echo "archive: no ticket matching $ID" >&2; false; }
[ -f "$f" ] || { echo "archive: $ID does not match exactly one ticket" >&2; false; }
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
  NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }  # front matter starts at line 1 only
  in_fm && /^---[[:space:]]*$/ {                             # …and ends at the first closing fence
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
The guards reject a missing ticket, an ambiguous ID, and an empty resolution before the
first write. One fence-scoped `awk` pass updates `status`, `updated`, and `resolution`.
`resolution` is inserted or replaced. Missing front-matter fails, and values pass through
`ENVIRON` without `sed` replacement processing.

The roadmap rewrite is published through `$R.tmp` and `mv`. It matches the full immutable ID
in the first ID-bearing cell, not a `Needs` mention or longer ID. Zero or multiple matching
rows print the count, exit non-zero, and leave the roadmap unchanged. An already-struck row
is unchanged.

**Roadmap consistency check** (run after creating, archiving, or re-wiring tickets).
The shared tree guard from the prefix setup is restated so a copied block still fails
closed when `.ai/sift` is missing; a consistent tree stays silent:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
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
Extraction accepts the full numeric suffix, including IDs above 9999. Both comparisons use
whole-ID boundaries, so `<PREFIX>-00420` cannot satisfy `<PREFIX>-0042`.

**Validate front-matter across the tree** (files missing a required key). Same tree
guard as above; when every required key is present the loop prints only the section
headers and exits 0 — including on a tree that holds no tickets at all:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
for k in id title status type milestone priority effort created updated; do
  echo "== missing $k:"
  grep -rL "^$k:" .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md" || [ $? -eq 1 ]
done
```
`|| [ $? -eq 1 ]` accepts grep's no-match status for an empty tree but preserves real grep
errors. Do not replace it with `|| true`.

**Find tickets archived without a `resolution`**. Resolution becomes required when `status`
is terminal, regardless of the current folder. A conforming tree prints nothing:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^status:/ { st = $2; next }
    infm && /^resolution:/ {
      res = $0
      sub(/^resolution:[[:space:]]*/, "", res)
      gsub("[\047\"[:space:]]", "", res)
      next
    }
    END {
      if (st == "done" || st == "wontfix" || st == "superseded")
        if (res == "") print "ARCHIVED WITHOUT RESOLUTION: " FILENAME
    }
  ' "$f"
done
```
The absent key, a blank value, `""`, and `''` all count as empty. The pass reads only leading
front-matter. A missing `status:` belongs to the required-key validation above.

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

**Machine-check a draft — optional, only if `xmllint` is already installed.** Hand-rendered
tickets are valid. Without the binary, the guard reports a skip and exits successfully:
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
The fence walk ignores body text. For `MISMATCH:`, move the file to match authoritative
front-matter. For `NO MILESTONE:`, add a non-empty front-matter key.

**Refresh the installed convention** by copying only `README.md` and `schemas/*.xsd`.
Everything else under `.ai/sift/` is repository state and must not be overwritten.

The initializer never refreshes files automatically. It reports each byte-different file as
`stale`, followed by the two commands below with the paths already resolved:

```sh
cp "$SKILL/assets/README.md" .ai/sift/README.md
cp "$SKILL"/assets/schemas/*.xsd .ai/sift/schemas/
```

`$SKILL` is the `sift-init` skill directory. Run `sift-init.sh` and use its resolved commands;
diff local annotations before copying. Current files produce no `stale` line.

Refresh never removes files. A schema absent from `assets/schemas/` is reported as `orphan`
with a suggested `rm`; the initializer does not execute it.
