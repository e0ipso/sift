# kk-curate batch agent prompt

Read this before dispatching a drafting sub-agent on the parallel path (Step 2). Dispatch each sub-agent with the instructions below, substituting `<list>` (the batch's absolute session-file paths) and `<DRAFT_PATH>` (its predetermined absolute output path). The action mappings are inlined so the sub-agent does not need to read the parent skill. The shared admission and modification-restraint criteria live only in their canonical file, which the sub-agent reads directly.

> You are drafting curator actions for ONE batch of pending session logs.
> - The batch contains these session files at absolute paths: `<list>`.
> - Read every file in full. Each session's frontmatter `proposals:` block has `practice: [...]` and `map: [...]` arrays whose entries are `{ type, tags, title, description, body, kk_confidence }`.
> - Read `.ai/kenkeep/.config/prompts/knowledge-admission.md` in full before deciding actions. Apply its admission criteria, keep test, salvage rule, modification restraint, and no-op rule as written.
> - For each candidate (in array order), decide one action and build a `CuratorAction` object. Use `candidate_origin = "<session_id>:<practice|map>:<index>"` (zero-based).
> - Action rules (full headings in the parent skill's "Action rules" subsection; the one-line restatement below is sufficient for batch drafting):
>     - **add**: candidate is genuinely new; no existing node already covers its scope. `target_node_id: null`.
>     - **modify**: an existing node covers the same scope and the candidate refines it without negating it; verify `target_node_id` exists on disk first; rewrite the merged body in present-tense end-state (no "previously…" prose), subject to the canonical modification-restraint criteria.
>     - **contradict**: candidate directly negates an existing valid node (both cannot be true at the same scope); set `target_node_id` to the tightest-scope match.
>     - **drop**: near-rephrasing, low-signal, general programming knowledge, change-oriented framing, non-productive provenance signals, or anything ruled out by the canonical admission criteria; `target_node_id: null`, `proposed_node: null`.
> - For a **map** candidate, set `kk_relates_to` to the practice nodes that govern changing that entity (the "watch out when editing this" knowledge lives there), and keep a short optional "When changing this, verify…" clause in the body only when the session evidenced a concrete edit-time check — never invent one.
> - Hard constraints: never cross the practice/map boundary; `proposed_node` keys are `title|type|tags|description|body|kk_confidence|kk_relates_to|kk_depends_on` (any other key will be rejected downstream). Validate your output array with `npx --yes kenkeep@latest validate curator-output <DRAFT_PATH>` if you can; the host re-validates and skips a malformed batch.
> - Write the actions as a JSON array (top-level) to the absolute path `<DRAFT_PATH>`. The file must contain exactly the JSON array, nothing else.
> - Return the path on success.
