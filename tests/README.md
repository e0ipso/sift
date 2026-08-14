# tests

The suite for a convention that forbids installable dependencies has to obey the
same rule, so there is no framework, no runtime and no lockfile here: every test
is a shell script that prints TAP-ish lines and one summary line, and `run.sh`
adds them up.

```sh
tests/run.sh                      # everything
tests/run.sh cookbook static      # one or more groups
SIFT_TEST_VERBOSE=1 tests/run.sh  # stream every assertion, not just failures
SIFT_TEST_KEEP=1 tests/run.sh     # leave the temporary trees on disk to inspect
```

Exit code 0 means green. Every fixture lives under a `mktemp -d` that is removed
on exit, including on failure; nothing in the suite writes inside the repository.

## Groups

| Group | What it covers |
|---|---|
| `cookbook/` | the recipes in `README.md`, run as written against throwaway trees |
| `scripts/` | the shipped card scripts through their real command lines |
| `static/` | the portability bans, shell lint, the XSD drafting schemas, the claims one repository document makes about another file, the test libraries' own behaviour — `lib/harness.sh`'s assertion arms and the ticket shapes `lib/fixtures.sh` produces — and the suite's own no-dependency / determinism / cleanup contract |
| `e2e/` | one full gate → init → allocate → archive → roadmap-check lifecycle |

`cookbook/` does not paraphrase the recipes: `lib/recipes.sh` extracts the fenced
block out of `README.md` by its anchor line and runs that text. A recipe that
drifts from its documentation is the failure these tests exist to catch, so a
reworded anchor is *supposed* to break them.

The normative blocks that are *not* ` ```sh ` recipes are held to the same terms.
The front-matter example, the directory layout, the three body templates, the
run-log row schema and the refresh recipe each have a named extractor in
`lib/recipes.sh`, and the tests compare against those rather than against a
hand-copied constant: the required key list against the validation recipe's own
`for k in …`, the closed `type` set across its three copies (layout tree,
front-matter example, XSD enumeration), each backfill recipe's heading against
the template that names it, `drain-log`'s log header and column order against the
run-log block, `convention-assets`' two `cp` lines against the refresh block, and
`sift-init-tree`'s entry set against the layout block. An extractor whose output
nothing compares against is decoration, so each one lands with its comparison,
folded into the file that already owns the subject. Two rules go with them: every
caller asserts the extraction is non-empty before comparing, so a reworded anchor
fails on the extraction instead of passing a comparison of two empty sets; and a
comparison that can only run one way — `sift-init-tree`'s, because the layout
block draws shape as well as paths — carries an explicit excused list with a
reason per entry, and asserts the excused entries are still documented.

Two of those artifacts are not `lib/recipes.sh`'s business, and their readers
live in `static/schemas.test.sh` instead, where their only caller is. The worked
XSD draft is reduced to the elements it opens, in document order and with their
nesting depth, and compared against `schemas/*.xsd` three ways: every name is
declared, the top-level sequence is an ordered *subsequence* of the declared one
because optional elements may be omitted, and nothing declared without
`minOccurs="0"` is missing. The render-mapping table beside it is read cell by
cell — the only markdown table this suite parses — and both its columns are
resolved, the left against the schemas and the right against the three body
templates, with the reverse direction closed too so a schema that grows a body
element gets a row or a failure. All of it is textual: a lexical read of
`xs:element name="…"` is not XSD validation, so datatypes, patterns and
cardinality past "optional or not" stay with `xmllint` where the machine has it.
That split is the point rather than a compromise — the structural half needs no
binary, so it holds on the machine the convention actually targets.

Coverage there is per subject, not per file: `allocate-id`, `archive` and
`move-milestone` own the recipes that write, `query` and `labels` own the ones
that only read, and `validation` owns everything that audits a tree. The read-only
files also assert a `tree_digest` across every recipe they run, because a query
that mutates the tree is the one bug reading the output can never reveal. Each
recipe is exercised on empty input as well as populated: a fresh `sift-init` tree
is empty, so that is the first state any of them meets.

`scripts/` is organised the same way, per subject rather than per file:
`sift-gate`, `sift-init-prefix`, `sift-init-milestone` and `sift-init-tree` own
the initializer's resolution, its two validators and its write path;
`convention-assets` and `sync-assets` own the shipped spec; `reserve-ids` owns ID
allocation; `roadmap-check` owns rule-9 consistency; `drain-selection` owns
next-ticket/wave-status; `drain-log` owns the run log; `labels` owns the drain's
label index (list-labels/tickets-by-label); `prime-backlog` owns the two ends of
a priming pass, existing-work's dedupe corpus and roadmap-append's write. Root
and prefix resolution is the one contract every card script shares, so it is
swept across them once, in `root-resolution`, instead of being re-asserted per
file.

That sweep takes every card script that can be run without writing, both cards
included. The two writers are the named exception, and each holds the same
contract in its own file instead — `drain-log.sh` in `drain-log`, and
`roadmap-append.sh` in `prime-backlog` — driven by a real write command line, so
what gets refused is the write. They cannot join the sweep because its cases run
one command line against every entry: the sweeps asserting a *successful*
resolution would append to the fixture tree, and the invocations that would not
(`drain-log.sh report` on a tree with no `RUNLOG.md`, `roadmap-append.sh` with
the wrong argument count) refuse for reasons of their own before the resolved
root is ever used, which is not the failure the sweep is asserting.

`static/suite-contract.test.sh` holds the suite to its own promises: it runs a
generated child test file and checks the temporary tree is gone afterwards on the
passing, failing and died-before-summary paths, and it runs the end-to-end
lifecycle with `PATH` pointing at a symlink farm of baseline POSIX utilities and
nothing else. That list of utilities is the dependency contract — adding a name
to it is a decision to depend on that tool.

The farm is also what keeps an optional binary honest in the other direction. A
check that only ever runs when the tool happens to be installed is no check at
all on the machine the convention targets, so `static/schemas.test.sh` tags the
cases that must survive without one `@BASELINE-CASE`, and the contract file
extracts those names and runs that file through the farm, asserting an `ok` line
for each. Moving a tagged case back inside its `command -v` arm makes those lines
disappear and the contract case red.

Three more promises are asserted there rather than described. A fourth generated
child drives every assertion helper through both of its arms, so a helper that
reported `ok` for a false claim — or `not ok` for a true one — is caught along
with a miscounted `T_ASSERTS`. `SIFT_TEST_VERBOSE` is driven through a `cp` of
the shipped `run.sh` over a generated child, once plain and once with the
variable set, since the flag lives in `run.sh` rather than in the harness. And
the no-writes digest walks the whole of `REPO_ROOT` minus a named exclusion list
carrying a reason per entry, taken around a run of every other test file in the
suite rather than around one heavy writer — a failure there names no single
culprit, so it prints the difference between the two digests. Every entry on that
list names a writer that runs outside the suite, and each one narrows the promise,
so the list is audited by a case of its own: it prunes `.git`,
`.ai/kenkeep/_sessions` and `.ai/kenkeep/.state` against a fixture root and then
damages a file under the sibling `.ai/kenkeep/nodes`, which is repository content
and has to stay reported.

## The portability matrix

The convention promises the recipes run on the Unix userland already present, on
both GNU and BSD systems. Where a recipe's behaviour could turn on the shell, the
`awk` implementation or the locale, one representative scenario is replayed
across all of them — `bash`/`dash` × `gawk`/`mawk`/`nawk` × `C`/`C.utf8`/
`en_US.utf8` — via `for_matrix` in `lib/recipes.sh`. Recipes built only from
`grep`, `sed` and `find` use `for_shell_locale`, which drops the axis that has
nothing to vary. Every member of those axes except `bash` and `C` is an
installable extra, so a member the machine does not have is skipped: the sweep
narrows, the run stays green, and the suite keeps needing nothing but the
baseline. The locale axis is inside that sentence, not an exception to it —
`locale_available` in `lib/recipes.sh` probes each name by running it and skips
the ones the machine lacks, because a leg labelled `en_US.utf8` on a host that
falls back to `C` asserts nothing about collation.

One combination is excluded from both sweeps: the environment `recipe_runner`
falls back to when a case pins nothing — `bash`, `C`, and the `awk` that `PATH`
resolves — because that is the environment every plain case in the file already
ran in, and a leg repeating it re-asserts, through a callback that reports a
label rather than an expected/actual pair, what the plain case above it asserted
in full (SFT-0078). The exclusion is derived from `RECIPE_DEFAULT_SHELL` /
`RECIPE_DEFAULT_LOCALE` / `RECIPE_DEFAULT_AWK` rather than written out a second
time, and its `awk` half is decided at runtime by inode against `command -v awk`,
so `bash/mawk/C` on a host whose `awk` is gawk is a real leg and keeps running.
It removes one combination, never an axis member: every shell, every `awk` and
every locale the machine has is still entered.

So a sweep *can* now narrow to nothing — on a host with no `dash`, no second
`awk` and no UTF-8 locale, every combination left is the excluded baseline. What
still covers the recipe there is the plain case above the sweep, which is why
each sweep is required to sit under one asserting at least what its dropped leg
asserted. The empty sweep is audible rather than silent: `for_matrix` and
`for_shell_locale` report it through the harness's `skip`, naming the excluded
combination, so it lands in the `# SUMMARY … skipped=` count and in `run.sh`'s
SKIP-reason line like any other named gap. `static/suite-contract.test.sh` drives
that path for real, by running a matrix file against the baseline-only PATH farm.

The GitHub Actions job and the dev container both use Linux, so no BSD host is
available there and the BSD half of the promise is covered statically instead:
`static/portability.test.sh` fails the build on `sed -i`, on `xargs -r`, on a
`[ \t]` bracket expression in `awk`, and on a collated `[a-z]`-style range in a
shell glob or `case` pattern. That file also carries a `skip` naming the gap, so
the blind spot is reported by the suite rather than only described here;
closing it needs a BSD runner, not an assertion.

## Destructive and concurrent sequences

A guard is only worth asserting if the thing it guards against would really have
happened, so `sift-init-milestone` puts a populated tree exactly where a
traversing `--milestone` points and runs the escape unguarded before asserting
the guarded run leaves it alone. Without that positive control a miscounted `..`
looks identical to a guard that held.

The race in `sift-init-tree` launches its writers together and reaps them with
`wait`; the overlap is real but not forced. Forcing it would take a FIFO — a name
the dependency contract in `static/suite-contract.test.sh` does not list — or a
sleep-based spin, which this repo forbids, so the assertions are written to hold
under every interleaving instead. Do not "fix" that with a sleep: the correct
move is a narrower assertion, or a `skip` naming the ticket.

## Writing one

Source the three libraries, name each case, assert, and finish with `summary`:

```sh
. "$DIR/../lib/harness.sh"    # assertions, temp dirs, run_cmd
. "$DIR/../lib/recipes.sh"    # README extraction, run_recipe, the matrix
. "$DIR/../lib/fixtures.sh"   # make_tree, ticket, roadmap_row, fm

test_case "what is being pinned"
assert_eq "$want" "$got" "why it matters"
summary
```

`summary` is required, and it is the last call for a reason: `run.sh` fails any file
that exits without printing the `# SUMMARY` line, whatever its exit status. A file that
returned early, was truncated, or died on the way there ran fewer cases than it claims,
so an absent summary is reported as a failure naming the file rather than counted as a
file of zero tests.

`ticket` takes extra front-matter lines after the title. A line naming one of the
required keys *replaces* that key's default rather than appending a second copy,
so `ticket … 'type: feature'` yields a feature ticket instead of a file claiming
both types — which matters the moment a recipe greps for one of them. Any other
`key: value` line is written verbatim inside the fence, which is how an optional
key like `source:` gets set.

The body follows the same replace-not-append rule through a selector rather than
a line: `ticket … body=canonical` yields the four canonical sections,
`body=bug` and `body=feature` the type-specific templates, and
`body=adversarial` the shared body the two front-matter rewrites are pinned
against — prose quoting `status:`, `updated:`, `resolution:` and `milestone:` at
column 0, under a plain and a spaced `---` rule. The selector carries an equals
sign rather than a colon precisely so it cannot be mistaken for a front-matter
key, and it is excluded from the pass-through, so it never appears in the
produced file. Three things about it are deliberate. The default body is
unchanged and stays that way, because this library is sourced by every group and
a changed default rewrites the input of every existing assertion. The shape is
never derived from `type:` — the bug-backfill recipe's positive case is a
`type: bug` ticket with *no* `## Expected behaviour`, which a derived body could
not build. And the headings are README's, verbatim: a heading is parsed API, so
`cookbook/validation.test.sh` asserts each shape against the template extracted
from `README.md` rather than trusting the copy.

`config_yaml <dir> <shape>` is the same idea for the tree's config file:
`make_tree` keeps writing a bare `prefix:` line, and a case that means to pin a
shape asks for `commented` (the `#` header `sift-init.sh` installs) or `inline`
(README's trailing comment) explicitly, so the assertion is somewhere a reader
can see it.

Fold a new behaviour into the file that already owns its subject; add a file only
for a subject none of them covers. When a test fails because the product is
genuinely wrong, file a sift ticket and `skip "<behaviour>" "<TICKET-ID>"` rather
than deleting the case or fixing the product from here.
