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
├── README.md                  ← this convention (read it before touching tickets)
├── MILESTONES.md              ← what each milestone means, in intended order
├── ROADMAP.md                 ← advisory resolution order (tickets' depends_on is the truth)
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

## File naming

`<PREFIX>-<NNNN>--<kebab-slug>.md`

- `<PREFIX>-<NNNN>` is the ticket ID: zero-padded, sequential, **immutable, never
  reused**, globally unique across both buckets. The prefix comes from the
  *Configuration* section above. The slug may be edited; the ID may not.
- Allocate the next ID by looking at the highest existing one (see cookbook below).

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

Use these sections (omit ones that are genuinely empty, keep the order):

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

## Operations cookbook (terminal)

All commands assume you run them from the repository root
(`.ai/sift/...` paths) — adjust if elsewhere.

**Set the prefix once per shell.** Every recipe below reads `$PREFIX`; export it first
and nothing else needs editing when the prefix changes:
```sh
export PREFIX=$(grep -m1 '^prefix:' .ai/sift/config/config.yaml | awk '{print $2}' | tr -d "\"'")
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

**Allocate the next ID** (highest existing + 1, across both buckets):
```sh
find .ai/sift -name "$PREFIX-*.md" | sed 's#.*/##' | grep -oE "^$PREFIX-[0-9]{4}" | sort | tail -n 1
```

**Triage view — id, title, priority for one milestone:**
```sh
grep -r --include="$PREFIX-*.md" -H '^title:' ".ai/sift/open/$MILESTONE" | sort
grep -rl '^priority: p1' .ai/sift/open        # all critical tickets
```

**Count open tickets per milestone:**
```sh
for m in .ai/sift/open/*/; do printf '%-28s %s\n' "$(basename "$m")" "$(find "$m" -name "$PREFIX-*.md" | wc -l)"; done
```

**Find a ticket wherever it lives:**
```sh
find .ai/sift -name "$PREFIX-0042*"
```

**Full-text search (e.g. every ticket touching one symbol or subsystem):**
```sh
grep -ril 'cache invalidation' .ai/sift --include="$PREFIX-*.md"
```

**Who depends on `$PREFIX-0042`:**
```sh
grep -rl "$PREFIX-0042" .ai/sift --include="$PREFIX-*.md" | grep -v "$PREFIX-0042--"
```

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
sed "s/^milestone: .*/milestone: $DEST/" "$t" > "$t.tmp" && mv "$t.tmp" "$t"
```

**Archive a finished ticket** (then strike its row in `ROADMAP.md` — rule 9):
```sh
f=$(find .ai/sift/open -name "$PREFIX-0042--*.md")
sed -e 's/^status: .*/status: done/' \
    -e 's/^resolution: .*/resolution: "Fixed in commit abc1234"/' \
    -e "s/^updated: .*/updated: $(date +%F)/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
dest=$(printf '%s\n' "$f" | sed 's#/open/#/archive/#')
mkdir -p "$(dirname "$dest")" && mv "$f" "$dest"
```

**Roadmap consistency check** (run after creating, archiving, or re-wiring tickets):
```sh
# Every ticket (open or archived) must appear in ROADMAP.md ...
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]{4}" | sort -u | while read -r id; do
    grep -q "$id" .ai/sift/ROADMAP.md || echo "NOT IN ROADMAP: $id"
  done
# ... and every roadmap ID must correspond to a ticket file somewhere.
grep -oE "$PREFIX-[0-9]{4}" .ai/sift/ROADMAP.md | sort -u | while read -r id; do
  find .ai/sift/open .ai/sift/archive -name "$id--*.md" | grep -q . || echo "STALE IN ROADMAP: $id"
done
```

**Validate front-matter across the tree** (files missing a required key):
```sh
for k in id title status type milestone priority effort created updated; do
  echo "== missing $k:"; grep -rL "^$k:" .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md"
done
```

**Sanity-check folder/front-matter agreement:**
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | while read -r f; do
  m=$(grep -m1 '^milestone:' "$f" | awk '{print $2}')
  case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
done
```
