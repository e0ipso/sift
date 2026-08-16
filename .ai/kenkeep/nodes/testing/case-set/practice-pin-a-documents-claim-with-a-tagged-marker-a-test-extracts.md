---
type: practice
title: Pin a document's claim with a tagged marker a test extracts
description: >-
  A fenced @TAG: line is the claim; the test extracts it, resolves it against
  the live tree, and proves the guard on a damaged copy.
tags:
  - testing
  - docs
  - convention
  - sift
  - shell
kk_schema_version: 3
kk_id: practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts
kk_derived_from: []
kk_relates_to:
  - practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test
  - practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version
  - practice-prove-the-damage-before-asserting-the-guard
kk_depends_on: []
kk_confidence: high
---
Two static tests share one shape, and it is the established idiom for any claim a
document makes about the tree. `tests/static/prompt-readme-sections.test.sh` reads the
`@README-SECTION:` lines out of `src/skills/sift-drain/references/ticket-agent-prompt.md`
and asserts each named heading exists in README.md *and* in the shipped `sift-init`
mirror. `tests/static/agents-skill-copies.test.sh` reads the `@SKILL-COPY:` lines out of
AGENTS.md's "Duplication between skills" and asserts the named file exists and that some
non-comment line of it still holds the named construct. The marker line inside a fenced
block is the form; the prompt's list already sits inside its own template fence, so there
the marker is a bare line prefix instead.

Three properties make the shape work, and each was earned. The test holds **no copy** of
the list — a list restated in a test is a third place to forget, which is the drift being
guarded rather than a demonstration of it. The extraction's **non-emptiness is its own
assertion**, because a parse that silently yields nothing satisfies every "still there"
check vacuously and reports agreement on a record naming nothing (the SFT-0010 shape).
And the comparison is factored out so it can run against a **deliberately damaged copy**
— a construct deleted from a throwaway checkout, and an entry rewritten to cite a file
that does not exist — so a green run means the guard can still fail. Comment lines are
excluded from the haystack on purpose: both skills explain their copy at length directly
above it, and an entry satisfied by a sentence *about* a construct would survive that
construct's deletion.

What gets pinned is a **name, never a line number**. SFT-0042 first wrote the skill-copy
inventory as eight `file:line` citations and SFT-0043 took the numbers back out: SFT-0038,
SFT-0041 and SFT-0042 had each added comment lines directly above one of those constructs,
so pinned numbers would have failed the suite three times without a single copy moving.
That churn trains a maintainer to bump a number without reading what it points at, which
is the believed-but-wrong reference the record exists to prevent, one level down. The cost
of the choice is recorded in the section too: a construct that merely moves *within* its
own file is not drift this shape detects, and `grep -n` recovers a line number whenever a
reader wants one.

Both tests also assert that the document names the test file that reads it, so deleting
the documentation of the coupling breaks the build rather than quietly orphaning it.

The shape has since been reused twice more, and copying either precedent verbatim breaks
the new check in the opposite direction each time. `@PIN:` (SFT-0047,
`tests/static/skill-prose-pins.test.sh`) pins every claim a skill's prose makes about
a file that lives elsewhere — a `references/*.md` prompt, the gate's state names, an XSD
root element, README's body headings. Its haystack is the **raw** file, because
`agents-skill-copies`' comment filter is right for shell and fatal here: a markdown ATX
heading is a line starting with `#`, so a filtered haystack would look for `## Problem` in
a file it had just stripped every heading from. Its fenced blocks are **not** excluded,
because `prompt-readme-sections` skips them to avoid sample headings while the targets
here sit inside README's fenced layout and body blocks. Know which of the two filters is
wrong for your target before reaching for either. `@BASELINE-CASE` is the fourth
mechanism, and the smallest: `tests/static/schemas.test.sh` tags the cases that must
survive the baseline-utility farm, and `suite-contract` extracts the names and asserts an
`ok` line for each in the restricted run.

`@PIN:` is also the first with two kinds of target, and the second kind exists only to
stop a marker satisfying itself. A target ending in `/` is a skill *directory*, and its
construct is resolved against that directory's `SKILL.md` **front matter only** — the
claim being pinned is that the skill's `name:` key equals the directory holding it, and a
whole-file match would be satisfied by the marker line, which spells the name too. Its
negative case moves the `name:` line out of the front matter and into the body of a
throwaway copy and asserts the pin still fails with the string still in the file.

Two smaller rules travel with the family. A marker whose *form* is being documented goes
in an inline code span, never on a line of its own, or the documentation parses as a
marker and the extractor pins whatever the template says. And the standing ceiling of
every one of these mechanisms is that deleting a tag and moving the thing it guarded in
the same edit withdraws both claims and passes. That was weighed and left: it is a
deliberate edit to a line whose comment says what it is for, and the alternative is a more
brittle mechanism that fails on things nobody changed.

<!-- kk:related:start -->
# Related

- Related: [practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test](/practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test.md)
- Related: [practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version](/practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version.md)
- Related: [practice-prove-the-damage-before-asserting-the-guard](/practice-prove-the-damage-before-asserting-the-guard.md)
<!-- kk:related:end -->
