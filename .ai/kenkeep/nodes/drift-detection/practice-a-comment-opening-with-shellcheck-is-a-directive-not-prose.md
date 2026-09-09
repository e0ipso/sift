---
type: practice
title: 'A comment opening with the word shellcheck is a directive, not prose'
description: >-
  A malformed # shellcheck directive is SC1073, an error that aborts the parse
  of the whole file and hides every finding below it.
tags:
  - shell
  - lint
  - testing
  - gotcha
  - portability
kk_schema_version: 3
kk_id: practice-a-comment-opening-with-shellcheck-is-a-directive-not-prose
kk_derived_from: []
kk_relates_to:
  - map-sift-test-suite-runs-the-readme-recipes-themselves
  - practice-the-collated-range-scan-targets-globs-not-usage-strings
kk_depends_on: []
kk_confidence: high
---
shellcheck reads any comment whose first word is `shellcheck` as a directive. Prose that
happens to start with the tool's name is therefore parsed as one, fails to parse as one,
and reports SC1073/SC1072 — at *error* level. An error aborts the parse of that file, so
every finding below the comment is silently never reported. The lint looks clean on a file
it stopped reading at line 4.

`tests/static/shell-lint.test.sh` carried exactly that: a header paragraph opening
"shellcheck is not assumed to be installed…". It masked an SC2046 fifty lines further
down, on the arm's own invocation. The trap bites twice, because the natural place to
write a justification for a real `# shellcheck disable=SC2034` is the comment lines
immediately above it — and those are the lines most likely to begin by naming the tool.

Reword so no comment line starts with the bare token: "Nothing here assumes shellcheck is
installed…", "no reader for it exists in this file…". Naming the tool mid-line is fine;
only the first word after `#` is read as a directive key.
