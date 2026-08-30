# Proposal extraction prompt

<!--
  Version: 9
  Used by: the kk-proposal-drain hook (via a headless harness session)
  Owner contract: produces the structured `proposals.practice` and `proposals.map` arrays
  for a session log. Must emit one JSON object on stdout as the final message.
-->

Extract reusable project knowledge from the role-tagged transcript below. Each segment starts
with `[USER]:` or `[AGENT]:`. Apply this admission procedure in order.

## Admission procedure

### 1. Decide the session disposition

Judge the session as a whole before extracting candidates. Reject the whole session when any
of these shapes applies:

- **Abandoned or dead-end.** The user reverses an approach without choosing a replacement.
  Phrases such as "never mind", "let's defer this", or "don't bother" are common signals.
  This differs from a correction such as "don't do X, do Y", which supplies a replacement.
- **Exploratory or open-ended.** The session surveys options, asks questions, or floats
  hypotheses without committing to an end-state claim.
- **Unrelated or off-project.** The work concerns general programming, another repository,
  personal conversation, or support unrelated to this project's modules, terms, or rules.
- **Meta-only.** The session plans, scopes, brainstorms, or sketches future architecture
  without establishing a current project rule or fact. Work confined to plan or task files,
  such as `.ai/task-manager`, is the standard case. A correction inside a meta-only session
  does not override this whole-session rejection.

If any shape applies, emit `{"practice": [], "map": []}` and stop. Do the same when the
disposition is ambiguous. Candidate quality does not affect this decision. A productive
session proceeds even if later steps reject every candidate.

### 2. Select candidates from allowed sources

Run separate practice and map passes.

- A **practice** is a project-specific convention, prohibition, gotcha, decision rationale,
  or workflow rule. Extract practices only from `[USER]:` turns. Agent paraphrases provide
  context, not evidence.
- A **map** describes a project-specific feature, term, canonical location, ownership
  boundary, architectural relationship, integration seam, dependency, or substantial
  component. Extract maps from `[USER]:` or `[AGENT]:` turns.

Treat a user correction such as "don't do X, do Y", "never use X", "stop doing X", or
"use Y instead" as a practice candidate. Record the resulting rule, plus any rationale, in
present tense. Step 3 still rejects corrections limited to the current task.

For a `[USER /self-review-apply ...]:` turn, inspect each narrated change in the following
`[AGENT NARRATION OF SELF-REVIEW ...]:` turn as a separate corrective candidate. Apply the
same source, scope, and durability rules to each one.

### 3. Require project scope and durable value

Keep a candidate only when it records knowledge the user had to teach, or a named project
concept that the transcript defines. Reject:

- accepted code, routine implementations, file reads, searches, and orientation steps;
- typos, syntax fixes, generic mistakes, standard framework behavior, and general
  programming knowledge;
- anything a future agent can recover by reading the codebase;
- a correction that only governs the current edit.

Task-specific markers include one-off variable names, a single non-load-bearing file or
function, phrases such as "in this PR" or "for this test", and directions such as "undo the
line you added". Judge the rule's scope, not where the user happened to state it. Keep a
project-wide rule mentioned during one PR. Drop a rule that stops applying outside that PR.
When the scope is uncertain, drop the candidate.

Apply `.ai/kenkeep/.config/prompts/knowledge-admission.md` as the source of truth for
durability. It rejects maintenance or lifecycle actions, project story or history, and
incidental facts presented as rules. A plan, ticket, issue, work-order, or task ID is a red
flag. Ask whether the candidate will still state a deliberate operating principle or current
structural fact six months from now, independent of the activity that surfaced it. If a
candidate mixes durable knowledge with an action or story, keep only the durable part.

### 4. State the end state

Write practices as current rules and maps as current facts. Remove transition narration such
as "used to", "renamed", "removed", "switched", or "migrated". Keep the resulting present
state when the transcript establishes it. Drop a candidate when removing the change story
also removes its meaning.

### 5. Enforce map independence and pass ownership

A named service, module, file, command, event, entity, or field inside a practice does not
automatically earn a map. Keep the map only if it answers a useful question about what the
subject is, where it belongs, or how it relates to the project after removing the practice.

Practice owns imperative knowledge, including what to do, what to avoid, and why. Map owns
independent structure. Split one statement across both arrays only when each result passes
its own admission test. The curator adds `kk_relates_to`; do not add it here.

When the transcript gives concrete editing guidance for a mapped entity, the map body may end
with one short `When changing this, verify...` sentence. Do not invent this clause.

### 6. Make each candidate atomic

Each candidate captures one indivisible concept. Keep the rule with the qualifiers,
boundaries, and rationale required to apply it. Split two concepts when a future agent could
apply or update either one without loading the other. Do not split a rule from the rationale
or boundary that makes it usable.

### 7. Validate the output

Emit exactly one JSON object with two keys, `practice` and `map`. Each key holds an array. A
candidate has exactly these fields:

- `type`: `"practice"` or `"map"`, matching its array.
- `tags`: 1 to 5 short lowercase tags. Prefer conventions visible in the transcript.
- `title`: a short imperative for a practice or a noun phrase for a map, about 80 characters
  or fewer.
- `description`: at most 140 characters.
- `body`: concise markdown, usually 1 to 4 short paragraphs. Include source rationale.
- `kk_confidence`: `"high"` for an explicit user statement with rationale, `"medium"` for
  an explicit user statement without rationale, or `"low"` for an inference.

Reject all extra candidate keys, including `supports_existing_node` and
`contradicts_existing_node`. Either array may be empty.

---

## Session-disposition example

**Input transcript:**

```
[USER]: I'm drafting a release-gate plan under .ai/task-manager. Can you outline success criteria?
[AGENT]: A CI run, a docs build, and a staging smoke test.
[USER]: Add "CI gate before merging" to the plan. I'll decide the rest later.
```

**Correct output:**

```json
{"practice": [], "map": []}
```

Step 1 rejects the session as meta-only. The rule-shaped phrase belongs to unfinished plan
content, not a current project convention.

## What you are looking for

After Steps 1 through 4, retained candidates fall into two arrays:

- `practice` contains project rules sourced from user turns.
- `map` contains independently useful project structure sourced from user or agent turns.

Step 5 owns overlap between the arrays. Step 6 decides whether closely related material is
one candidate or several.

## What you are NOT looking for

Apply Step 3 instead of treating routine session activity as knowledge. In particular, do not
turn accepted implementation work, exploration, general knowledge, or task-local corrections
into candidates. Apply Step 4 instead of recording change history. When in doubt, emit less.

## Ownership boundary example

This user statement contains both kinds of knowledge:

> "Use the rm_analytics dispatcher for tracking. It fans events out to the configured backend
> so modules do not depend on one vendor."

It supports a practice that requires the dispatcher and a map that describes the independent
fan-out relationship. If the statement only said the dispatcher "supports tracking", emit the
practice alone because the proposed map would add no structure.

## Inline example

**Input transcript:**

```
[USER]: Add caching to the profile page with Drupal's render cache.
[AGENT]: I'll add cache contexts and tags.
[USER]: No. Use rm_pii.cache for content with PII because it encrypts at rest. Drupal's default
cache stores plaintext in the database.
[AGENT]: I'll use rm_pii.cache.
```

**Correct output:**

```json
{
  "practice": [
    {
      "type": "practice",
      "tags": ["caching", "pii", "drupal"],
      "title": "Use rm_pii.cache for content with PII",
      "description": "Use the encrypted rm_pii.cache service instead of Drupal's plaintext cache for content with PII.",
      "body": "Content with personally identifiable information uses `rm_pii.cache` because it encrypts data at rest. Do not put that content in Drupal's default render cache, which stores plaintext in the database.",
      "kk_confidence": "high"
    }
  ],
  "map": []
}
```

Step 2 ignores the agent's cache-property suggestion and acknowledgement. Step 5 rejects a
companion `rm_pii.cache` map because it would repeat the practice without adding structure.

### Inline example: a self-review-apply turn

**Input transcript:**

```
[USER /self-review-apply feedback.xml]: /self-review-apply feedback.xml
[AGENT NARRATION OF SELF-REVIEW feedback.xml]: The review says loop variables in this codebase
use descriptive names. I renamed i to cardIndex. It also caught a typo in one JSDoc comment.
```

**Correct output:**

```json
{
  "practice": [
    {
      "type": "practice",
      "tags": ["naming", "readability"],
      "title": "Use descriptive loop variable names",
      "description": "Use descriptive loop variables such as cardIndex instead of single-letter counters.",
      "body": "Loop variables use names that identify the value being iterated, such as `cardIndex`. Do not use single-letter counters such as `i`, `j`, or `k`.",
      "kk_confidence": "medium"
    }
  ],
  "map": []
}
```

Step 2 treats the narrated review rule as a corrective candidate. Step 3 drops the typo because
it is a task-local generic fix.

## Output schema

Step 7 is the complete schema. The final message contains one JSON object and no prose. Use
this empty result when no candidate survives:

```json
{"practice": [], "map": []}
```

## Final instructions

Apply Steps 1 through 7 in order. Stop at Step 1 for a rejected session. Otherwise run both
source passes, filter each candidate, enforce the ownership and atomicity boundaries, and
validate every field. Emit the JSON object with no prose before or after it.

The transcript begins below.

---

[TRANSCRIPT PLACEHOLDER, substituted at runtime]
