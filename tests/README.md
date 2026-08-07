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
| `static/` | the portability bans, shell lint and the XSD drafting schemas |
| `e2e/` | one full gate → init → allocate → archive → roadmap-check lifecycle |

`cookbook/` does not paraphrase the recipes: `lib/recipes.sh` extracts the fenced
block out of `README.md` by its anchor line and runs that text. A recipe that
drifts from its documentation is the failure these tests exist to catch, so a
reworded anchor is *supposed* to break them.

## The portability matrix

The convention promises the recipes run on the Unix userland already present, on
both GNU and BSD systems. Where a recipe's behaviour could turn on the shell, the
`awk` implementation or the locale, one representative scenario is replayed
across all of them — `bash`/`dash` × `gawk`/`mawk`/`nawk` × `C`/`C.utf8`/
`en_US.utf8` — via `for_matrix` in `lib/recipes.sh`. Recipes built only from
`grep`, `sed` and `find` use `for_shell_locale`, which drops the axis that has
nothing to vary.

No BSD host is available in CI or the dev container, so the BSD half of the
promise is covered statically instead: `static/portability.test.sh` fails the
build on `sed -i`, on `xargs -r`, on a `[ \t]` bracket expression in `awk`, and
on a collated `[a-z]`-style range in a shell glob or `case` pattern.

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

Fold a new behaviour into the file that already owns its subject; add a file only
for a subject none of them covers. When a test fails because the product is
genuinely wrong, file a sift ticket and `skip "<behaviour>" "<TICKET-ID>"` rather
than deleting the case or fixing the product from here.
