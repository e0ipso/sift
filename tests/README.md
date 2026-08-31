# tests

The suite uses shell scripts and the Unix tools the convention already requires. It has
no test framework, runtime, or lockfile. Each test file prints TAP-like assertions and a
machine-readable summary that `run.sh` aggregates.

```sh
tests/run.sh                      # everything
tests/run.sh cookbook static      # one or more groups
SIFT_TEST_VERBOSE=1 tests/run.sh  # stream every assertion, not just failures
SIFT_TEST_KEEP=1 tests/run.sh     # keep temporary trees and print their paths
```

Exit code 0 means every selected file passed. Fixtures live under `mktemp -d` and are
removed on exit, including after a failure, unless `SIFT_TEST_KEEP` is set. Tests must not
write inside the repository.

## Groups

| Group | Contract |
|---|---|
| `cookbook/` | Runs the recipes extracted from `README.md` against throwaway trees. |
| `scripts/` | Exercises shipped skill scripts through their command-line interfaces. |
| `static/` | Checks repository-wide contracts such as portability, shell lint, schemas, document pins, and the test harness itself. |
| `e2e/` | Runs complete workflows across the public scripts and filesystem state. |

Run any group by passing its name to `tests/run.sh`. Cookbook and script cases are grouped
by subject, not by product file. Add a case to the file that already owns the behaviour;
create a test file only when no existing file owns that subject. Read-only cookbook cases
must compare `tree_digest` before and after, and recipes must be exercised against an empty
initialized tree as well as populated fixtures.

## Extracted documentation contracts

Cookbook tests call [`readme_block`](lib/recipes.sh) to extract the fenced shell block after
an anchor in `README.md`, then execute that exact text. A changed anchor or empty extraction
must fail the case. Do not copy a recipe into a test.

The same ownership rule applies to normative fenced blocks that are not shell recipes. Add a
named extractor in `lib/recipes.sh`, assert that it returned content, and compare it in the
test file that owns the subject. A one-way comparison must carry a documented exception list
and assert that every exception is still present. Keep schema-only readers beside their only
caller in [`static/schemas.test.sh`](static/schemas.test.sh); its lexical checks cover element
names, ordering, and required entries, while guarded `xmllint` checks may cover the rest when
that optional binary is installed.

## Suite contracts and failures

[`static/suite-contract.test.sh`](static/suite-contract.test.sh) owns promises made for the
whole suite: fixture cleanup, repository no-writes, deterministic output, assertion-helper
truthfulness, verbose output, and the baseline dependency set. Extend that file when a new
suite-wide promise is added. The baseline list is a dependency boundary; an added utility is
a new required dependency. Optional tools must stay behind `command -v`, and any case tagged
`@BASELINE-CASE` must pass without them.

Every test file must finish with `summary`. `run.sh` reports a file as failed if it exits
non-zero, records failed assertions, or prints no summary. The failure row names the file and
prints its non-passing output. Deliberate gaps use `skip <behaviour> <reason>` so the count and
reason appear in the final summary. Portability members unavailable on the current machine
use `matrix_narrowed`; these records are reported but do not change assertion or skip counts.

## The portability matrix

Use `for_matrix` when behaviour may vary by shell, `awk`, or locale. Use
`for_shell_locale` when the recipe does not invoke `awk`. Both helpers are defined in
[`lib/recipes.sh`](lib/recipes.sh). Put a plain case before the sweep that covers at least the
baseline behaviour, because the matrix deliberately excludes the runner's default
combination. The exclusion is derived from `RECIPE_DEFAULT_SHELL`,
`RECIPE_DEFAULT_LOCALE`, and `RECIPE_DEFAULT_AWK`; it removes one repeated combination, not
an axis member.

Shells, `awk` names, and locales beyond the baseline are optional. Missing members produce a
`NARROWED` record. If two `awk` names resolve to the same implementation, the first declared
name runs and later names are narrowed by inode identity. If no combination remains after
the baseline exclusion and other narrowing, `matrix_empty` emits one counted skip naming the
gap. The plain case still covers baseline behaviour.

The Linux suite cannot execute the BSD half of the portability promise. Keep its static bans
in [`static/portability.test.sh`](static/portability.test.sh), and keep the named skip that
records the missing BSD runner.

## Destructive and concurrent cases

A guard test needs a positive control proving the unguarded fixture would reach the protected
state. Build that control only in a disposable tree. Concurrency tests should launch the real
race and assert properties that hold under every interleaving. Do not add sleeps or FIFO
dependencies to force one schedule; narrow the assertion or add a ticket-backed skip.

## Writing a test

Source the helpers the file needs, name each case, assert, and call `summary` last:

```sh
. "$DIR/../lib/harness.sh"    # assertions, temp dirs, run_cmd, tree_digest
. "$DIR/../lib/recipes.sh"    # README extraction, recipe runners, matrix helpers
. "$DIR/../lib/fixtures.sh"   # sift trees, tickets, front matter

test_case "what is being pinned"
assert_eq "$want" "$got" "why it matters"
summary
```

The shared libraries have separate ownership:

- [`lib/harness.sh`](lib/harness.sh) owns assertions, case counts, temporary directories,
  command capture, and whole-tree comparisons.
- [`lib/recipes.sh`](lib/recipes.sh) owns README extraction and execution across the
  portability matrix.
- [`lib/fixtures.sh`](lib/fixtures.sh) owns throwaway sift trees and their front-matter and
  body shapes.

When product behaviour is wrong, file a sift ticket and use
`skip "<behaviour>" "<TICKET-ID>"`. Do not delete the case or repair product code from a
test-only change.

### Ticket fixtures

`ticket <dir> <bucket> <milestone/category> <id> <slug> <title> [extra...]` creates a complete
ticket. An extra `key: value` line replaces that required front-matter key's default; an
optional key is written inside the front-matter fence. The helper never appends a second copy
of a required key.

```sh
ticket "$tree" open foundation/feature SFT-0001 example "Example ticket" \
  'type: feature' 'source: fixture' body=canonical
```

Body selectors are `body=canonical`, `body=bug`, `body=feature`, and `body=adversarial`. The
selector replaces the default body, is never written into the ticket, and is never inferred
from `type:`. Keep the default body unchanged unless the tests that rely on it are updated as
one deliberate change. Use `config_yaml <dir> commented|inline` when a case needs to pin a
config shape; `make_tree` keeps its minimal default.
