---
type: practice
title: 'Scope a front-matter rewrite to the fence, not just to the line start'
description: >-
  A ^key: anchor still matches body prose, and sed's 1,/^---$/ range runs to EOF
  on a fence-less file: walk the fence in awk with an in_fm flag instead.
tags:
  - sift
  - shell
  - gotcha
  - cookbook
  - convention
kk_schema_version: 3
kk_id: practice-scope-front-matter-rewrites-to-the-fence
kk_derived_from: []
kk_relates_to:
  - practice-never-write-data-through-a-sed-replacement-text
  - practice-move-tickets-and-edit-front-matter-together
kk_depends_on: []
kk_confidence: high
---
A ticket is front matter *and* a body, and `^status:` matches in both. Anchoring a rewrite
to the start of a line therefore scopes nothing: `sed 's/^status: .*/status: done/'`
replaces a sentence of the author's `## Direction` with a front-matter line and exits 0.
The corruption has no output, no exit code and no signal except `git diff`, and archiving
is precisely the moment an operator stops reading the ticket. A repository that documents
this convention is the likeliest place to write such a line, because its tickets quote key
names for a living.

`sed`'s range address is the obvious scoping device and it is not safe enough for this.
`1,/^---$/` behaves correctly on a well-formed ticket — it cannot re-trigger, so a `---`
horizontal rule in the body does not widen it — but when a file has no closing fence the
range runs to end of file and rewrites everything, which is the original defect
reintroduced for exactly the malformed input a repair recipe meets. The GNU-only `0,/re/`
form is not available, and the replacement text is still re-scanned for `&` and `\1`.

Walk the fence in `awk` instead. Open on `NR == 1 && /^---$/` and close on the next `---`;
gate every rewrite rule on that flag, and take values from `ENVIRON` rather than `-v` or a
substitution so nothing re-scans them:

```awk
NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
in_fm && /^---[[:space:]]*$/   { in_fm = 0; print; next }
in_fm && /^status:/ { print "status: " ENVIRON["STATUS"]; next }
{ print }
```

The `[[:space:]]*` matters and SFT-0026 had to reconcile it: YAML permits a trailing space
after a document marker, and when the readers allowed one while the rewrites did not, a
valid ticket was front matter to every query and body to both writers. Widen the *close*
pattern as well as the open — the close is what ends the region, and a walk that enters and
never exits is worse than one that never enters.

Two details carry weight. Opening only at `NR == 1` is what stops a body `---` re-opening
the region — a plain `/^---$/ { in_fm = !in_fm }` toggle looks equivalent and is not, since
a rule and the lines after it fall back inside. And a rewrite that finds no key should fail
loudly rather than pass silently, because a front matter that disagrees with the folder is
the desync the convention exists to prevent.

Applied across the cookbook by SFT-0016 (the archive recipe's `status:`/`updated:` and the
move recipe's `milestone:`); the read-only `grep -m1 '^key:'` lookups have the same shape
without the destruction and are tracked separately as SFT-0020.

<!-- kk:related:start -->
# Related

- Related: [portability/practice-never-write-data-through-a-sed-replacement-text](/portability/practice-never-write-data-through-a-sed-replacement-text.md)
- Related: [tickets/practice-move-tickets-and-edit-front-matter-together](/tickets/practice-move-tickets-and-edit-front-matter-together.md)
<!-- kk:related:end -->
