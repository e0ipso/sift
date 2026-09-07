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
├── .id-sequence/              ← persistent per-prefix reservation marks and transient .lock/
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
- Reserve IDs through the cookbook allocator or a skill's `reserve-ids.sh`. It advances
  beyond both bucket filenames and `.id-sequence/<PREFIX>`, under one shared directory
  lock. Reserve before writing; keep unused reservations as gaps. Never lower or delete
  the reservation mark, even if a batch was interrupted.

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
wave: 1                # required positive integer while open; see rule 9
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

Each clustered ticket keeps its own `## Direction` and archive operation. Tickets that touch
the same product files run sequentially whether or not they share a `cluster`.

### The bounds a helper group is formed under

`next-ticket.sh --group` is a helper, not the drain loop. It picks the lead by dispatch order —
`wave` ascending, then `priority` within the wave — then walks forward through dispatchable
tickets with the lead's `cluster`. It excludes archived tickets and `status: blocked`;
`cluster` never reorders a wave.

A group holds **at most 4 tickets** and **at most 8 combined effort weight**:

| effort | xs | s | m | l | xl |
|---|---|---|---|---|---|
| weight | 1 | 2 | 3 | 5 | 8 |

The schema allows `s | m | l | xl`. The helper also assigns `xs` weight 1 and defaults an
absent or unrecognized effort to `m` weight 3. The first ticket that would exceed either
bound ends the group; it is not skipped. The group also ends at the first dispatchable
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

`schemas/` holds one XSD per body shape. Read each needed schema once as a field
checklist and write Markdown directly. An XML scratch draft is optional.
Draft into a scratch file outside `.ai/sift/` only when XML validation is useful;
render the markdown ticket, then delete the scratch file:

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

1. **Read this file before creating or moving tickets.** Read the applicable sections:
   Rules for agents, Front-matter schema, Ticket body, and Drafting a ticket for creation;
   the relevant cookbook recipe for allocation or moves. Follow them exactly.
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
9. **Give every open ticket a `wave: <n>` — set once, at drafting time.** Choose a wave no
   earlier than the latest wave among tickets it `depends_on`. Archiving does not touch it:
   an archived ticket keeps whatever wave it was drafted with, and the key is never required
   or edited after resolution. Then run the front-matter consistency check below — an open
   ticket with no `wave:`, or a `depends_on` ID pointing at nothing, is a convention
   violation.
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

**Allocate the next ID** (persistently reserves one; set `COUNT` for a contiguous batch).
Every writer, including parallel Prime and Drain sessions, must use this protocol:
```sh
(
  set -eu
  SIFT=${SIFT:-.ai/sift}
  COUNT=${COUNT:-1}
  [ -d "$SIFT/open" ] && [ -d "$SIFT/archive" ] || {
    echo "missing .ai/sift buckets — run sift-init first" >&2; exit 2;
  }
  printf '%s\n' "${PREFIX:-}" | LC_ALL=C grep -Eq '^[A-Z][A-Z0-9]*$' || {
    echo "invalid ticket prefix" >&2; exit 2;
  }
  case "$COUNT" in
    ''|*[!0-9]*) echo "count must be a positive whole number, got: $COUNT" >&2; exit 1 ;;
  esac
  COUNT=$(printf '%s\n' "$COUNT" | sed 's/^0*//')
  [ -n "$COUNT" ] || { echo "count must be at least 1, got: 0" >&2; exit 1; }
  [ "${#COUNT}" -le 9 ] || { echo "count is too large" >&2; exit 1; }
  mkdir -p "$SIFT/.id-sequence"
  LOCK="$SIFT/.id-sequence/.lock"
  if ! mkdir "$LOCK" 2>/dev/null; then
    echo "ID allocator busy or lock unavailable: $LOCK; retry after the owner finishes" >&2
    exit 3
  fi
  trap 'rm -f "$LOCK/files" "$LOCK/names" "$LOCK/ids" "$LOCK/numbers" "$LOCK/sorted" "$LOCK/top" "$LOCK/high"; rmdir "$LOCK"' EXIT
  trap 'exit 1' HUP INT TERM
  # Find the buckets explicitly so a symlinked .ai/sift shares the same state.
  find "$SIFT/open" "$SIFT/archive" -type f -name "$PREFIX-*.md" > "$LOCK/files"
  sed 's#.*/##' "$LOCK/files" > "$LOCK/names"
  LC_ALL=C grep -oE "^$PREFIX-[0-9]{4,}--" "$LOCK/names" > "$LOCK/ids" || [ "$?" -eq 1 ]
  sed "s/^$PREFIX-//; s/--$//" "$LOCK/ids" > "$LOCK/numbers"
  STATE="$SIFT/.id-sequence/$PREFIX"
  if [ -e "$STATE" ]; then
    SAVED=$(cat "$STATE")
    case "$SAVED" in
      ''|*[!0-9]*) echo "invalid ID reservation state: $STATE; restore it before allocating" >&2; exit 2 ;;
    esac
    printf '%s\n' "$SAVED" >> "$LOCK/numbers"
  fi
  # Refuse unsupported numbers rather than wrapping and issuing an old ID.
  awk 'length($0) > 15 { bad = 1 } END { exit bad }' "$LOCK/numbers" || {
    echo "ID exceeds supported numeric range" >&2; exit 2;
  }
  sort -n "$LOCK/numbers" > "$LOCK/sorted"
  tail -n 1 "$LOCK/sorted" > "$LOCK/top"
  HIGH=$(sed 's/^0*//' "$LOCK/top")
  HIGH=${HIGH:-0}
  LAST=$((HIGH + COUNT))
  [ "${#LAST}" -le 15 ] || { echo "ID exceeds supported numeric range" >&2; exit 2; }
  printf '%s\n' "$LAST" > "$LOCK/high"
  mv "$LOCK/high" "$STATE"
  # Publish the mark before printing. An interrupted caller loses IDs, never reuses them.
  N=$HIGH
  while [ "$N" -lt "$LAST" ]; do
    N=$((N + 1))
    printf '%s-%04d\n' "$PREFIX" "$N"
  done
)
```
The mark is written before IDs reach stdout. A failed caller may leave unused numbers;
never recycle them. `%04d` is minimum width, so 9999 advances to 10000. Allocation supports
IDs through 15 digits and refuses larger numbers rather than wrapping. Exit 3 means the
lock is busy or cannot be created: wait for its owner to finish, then retry the allocation.
Do not treat an error as an empty tree or use a read-only maximum as a fallback.

`.id-sequence/<PREFIX>` contains the highest reserved number, one decimal line. The
transient `.id-sequence/.lock/` serializes all writers sharing the tree, including worktrees
whose `.ai/sift` is a symlink. After a crash, stop allocation callers and establish that no
owner is running before removing only the lock's `files`, `names`, `ids`, `numbers`, `sorted`, `top`, and
`high` scratch files and its empty directory. Preserve every per-prefix mark. Restore a damaged mark from
a backup that includes outstanding reservations before allocating again.

Migration from read-only allocation is additive: stop old Prime/Drain sessions and update
both skills and this README before restarting writers. No ticket or key is renamed. The
first allocation creates `.id-sequence/` and seeds its mark from both existing buckets.
Outstanding IDs from an old read-only allocator must be written as tickets before restart;
otherwise they are not reserved. Include `.id-sequence/` when backing up the tracker.

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

**Archive a finished ticket** — the front-matter edit and the `mv` are one workflow, so run
them together:
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
```
The guards reject a missing ticket, an ambiguous ID, and an empty resolution before the
first write. One fence-scoped `awk` pass updates `status`, `updated`, and `resolution`.
`resolution` is inserted or replaced. Missing front-matter fails, and values pass through
`ENVIRON` without `sed` replacement processing.

**Front-matter consistency check** (run after creating, archiving, or re-wiring tickets).
The shared tree guard from the prefix setup is restated so a copied block still fails
closed when `.ai/sift` is missing; a consistent tree stays silent:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
# Every open ticket must carry a wave: key.
find .ai/sift/open -name "$PREFIX-*.md" | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^wave:/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$f" || echo "NO WAVE: ${f#.ai/sift/}"
done
# Every depends_on ID must resolve to a ticket file, open or archived.
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^depends_on:/ {
      sub(/^depends_on:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f" | while read -r dep; do
    find .ai/sift/open .ai/sift/archive -name "$dep--*.md" | grep -q . || \
      echo "UNRESOLVED DEPENDENCY: ${f#.ai/sift/} depends_on $dep, which has no ticket file"
  done
done
```
Wave membership and dependency edges are ticket front-matter; there is no second store for
either to fall out of step with.

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
