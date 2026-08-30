---
schema_version: 1
summaries:
  cli: >-
    the shipped scripts' CLI grammar — the -- end-of-options marker, subcommand
    slots and report-key collisions; read when adding an option, a subcommand or
    a report key to a script
  convention: >-
    cross-cutting project conventions including the file-based tracker premise
    and commit-message rules; read when changing standing repo conventions
    outside a single skill
  cross-skill: >-
    the rules sift-drain and sift-prime must classify alike — what a roadmap row
    is and what a ticket ID is — and how every copy is inventoried and guarded;
    read when touching either skill's row reader or ID check
  drift-detection: >-
    the repo's own static scanners and drift detectors — what the shellcheck and
    collated-range scans do and do not flag, and the rule that a detector prints
    its own remedy; read when adding a check under tests/static/ or working
    around a scan finding
  kenkeep: >-
    Kenkeep prompt ownership and knowledge lifecycle contracts; read before
    changing capture, curation, or admission rules
  portability: >-
    GNU/BSD recipe portability and no-installable-binary rules; read when
    writing cookbook recipes or shell helpers that must run on macOS and Linux
  shell: >-
    portable shell and awk recipe rules — quoting, globs, grep exit codes,
    fence-scoped rewrites and atomic publication; read when writing or editing a
    shell helper or a cookbook recipe
  shell/awk: >-
    awk-specific rules — embedded-program quoting, ENVIRON hand-off, field
    splitting and fence walking; read when writing or editing an embedded awk
    program
  shell/writes: >-
    writing into the tree safely — create-if-absent semantics, atomic
    publication, guard ordering and write-boundary validation; read when a
    recipe or script creates, replaces or moves a file
  sift-drain: >-
    sift-drain orchestration practices and the drain skill map; read when
    draining a roadmap, dispatching ticket agents, or changing wave-gate
    behavior
  sift-drain/orchestration: >-
    the drain worker graph, ownership boundaries, and reporting rules; read
    before changing dispatch or merge behavior
  sift-drain/tracker-runtime: >-
    tracker discovery, ignored-tree handling, and run-log timing semantics; read
    before changing drain paths or instrumentation
  sift-drain/verification: >-
    wave-gate coverage and shared-environment safety rules; read before changing
    drain test or live-check behavior
  sift-init: >-
    sift-init root gate and tree materialization; read when initializing
    .ai/sift, changing the project-root algorithm, or editing the tree-local
    gitignore
  sift-prime: >-
    sift-prime backlog-priming practices and skill map; read when priming or
    seeding the backlog, or changing proposal/dedupe/drafting behavior
  spec: >-
    normative README/AGENTS.md API and how the shipping spec may change; read
    when editing README.md or AGENTS.md convention text
  strikethroo: >-
    Strikethroo plan and task layout contracts; read before changing IDs, paths,
    or lifecycle rules
  testing: >-
    test-design rules for this suite — positive controls, interleaving-invariant
    assertions, diff-based proofs and document pins; read when adding or
    changing a case under tests/
  testing/assertions: >-
    what an assertion can and cannot see — the blind spots that make a case
    permanently green, and the positive controls, mutation probes and fixtures
    that prove a case can still fail; read before trusting or writing an
    assertion
  testing/case-set: >-
    how many cases a behaviour needs and which ones may go — sweeps and their
    narrowing lists, prose that overstates coverage, redundant per-item cases
    and non-interacting cross products; read when adding or deleting a case
  testing/coverage: >-
    how many cases a behaviour needs and which ones may go — sweeps and their
    narrowing lists, prose that overstates coverage, redundant per-item cases
    and non-interacting cross products; read when adding or deleting a case
  testing/suite: >-
    the shared harness and the rules for a run as a whole — what each library
    under tests/lib owns, what may enter the suite's verdict, and the no-write
    and concurrency constraints on a run; read before adding a helper or a test
    file
  tickets: >-
    ticket shape, lifecycle, and bookkeeping rules; read when creating, moving,
    archiving, or drafting tickets or changing front-matter/body schemas
---
# kenkeep Folder Summaries

- `cli`: the shipped scripts' CLI grammar — the -- end-of-options marker, subcommand slots and report-key collisions; read when adding an option, a subcommand or a report key to a script
- `convention`: cross-cutting project conventions including the file-based tracker premise and commit-message rules; read when changing standing repo conventions outside a single skill
- `cross-skill`: the rules sift-drain and sift-prime must classify alike — what a roadmap row is and what a ticket ID is — and how every copy is inventoried and guarded; read when touching either skill's row reader or ID check
- `drift-detection`: the repo's own static scanners and drift detectors — what the shellcheck and collated-range scans do and do not flag, and the rule that a detector prints its own remedy; read when adding a check under tests/static/ or working around a scan finding
- `kenkeep`: Kenkeep prompt ownership and knowledge lifecycle contracts; read before changing capture, curation, or admission rules
- `portability`: GNU/BSD recipe portability and no-installable-binary rules; read when writing cookbook recipes or shell helpers that must run on macOS and Linux
- `shell`: portable shell and awk recipe rules — quoting, globs, grep exit codes, fence-scoped rewrites and atomic publication; read when writing or editing a shell helper or a cookbook recipe
- `shell/awk`: awk-specific rules — embedded-program quoting, ENVIRON hand-off, field splitting and fence walking; read when writing or editing an embedded awk program
- `shell/writes`: writing into the tree safely — create-if-absent semantics, atomic publication, guard ordering and write-boundary validation; read when a recipe or script creates, replaces or moves a file
- `sift-drain`: sift-drain orchestration practices and the drain skill map; read when draining a roadmap, dispatching ticket agents, or changing wave-gate behavior
- `sift-drain/orchestration`: the drain worker graph, ownership boundaries, and reporting rules; read before changing dispatch or merge behavior
- `sift-drain/tracker-runtime`: tracker discovery, ignored-tree handling, and run-log timing semantics; read before changing drain paths or instrumentation
- `sift-drain/verification`: wave-gate coverage and shared-environment safety rules; read before changing drain test or live-check behavior
- `sift-init`: sift-init root gate and tree materialization; read when initializing .ai/sift, changing the project-root algorithm, or editing the tree-local gitignore
- `sift-prime`: sift-prime backlog-priming practices and skill map; read when priming or seeding the backlog, or changing proposal/dedupe/drafting behavior
- `spec`: normative README/AGENTS.md API and how the shipping spec may change; read when editing README.md or AGENTS.md convention text
- `strikethroo`: Strikethroo plan and task layout contracts; read before changing IDs, paths, or lifecycle rules
- `testing`: test-design rules for this suite — positive controls, interleaving-invariant assertions, diff-based proofs and document pins; read when adding or changing a case under tests/
- `testing/assertions`: what an assertion can and cannot see — the blind spots that make a case permanently green, and the positive controls, mutation probes and fixtures that prove a case can still fail; read before trusting or writing an assertion
- `testing/case-set`: how many cases a behaviour needs and which ones may go — sweeps and their narrowing lists, prose that overstates coverage, redundant per-item cases and non-interacting cross products; read when adding or deleting a case
- `testing/coverage`: how many cases a behaviour needs and which ones may go — sweeps and their narrowing lists, prose that overstates coverage, redundant per-item cases and non-interacting cross products; read when adding or deleting a case
- `testing/suite`: the shared harness and the rules for a run as a whole — what each library under tests/lib owns, what may enter the suite's verdict, and the no-write and concurrency constraints on a run; read before adding a helper or a test file
- `tickets`: ticket shape, lifecycle, and bookkeeping rules; read when creating, moving, archiving, or drafting tickets or changing front-matter/body schemas
