---
type: practice
title: 'Publish a staged write with ln, and restore the umask mode'
description: >-
  Stage beside the destination and link it in: ln's EEXIST is create-if-absent;
  mktemp's 0600 needs chmod +rw to honour the umask.
tags:
  - portability
  - concurrency
  - sift-init
kk_schema_version: 3
kk_id: practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode
kk_derived_from: []
kk_relates_to:
  - practice-check-then-act-cp-is-not-a-create-if-absent
kk_depends_on: []
kk_confidence: high
---
`install_file` and `write_file` in `src/skills/sift-init/scripts/sift-init.sh` stage every
write in a `mktemp` file inside the destination's own directory and publish it with `ln`.
The link is what makes the write atomic: `ln` fails with EEXIST when the name is taken, so
one syscall is both the "already there?" test and the create, and losing that race is the
"kept" branch rather than a failure. A bare `mv` would not do — it overwrites, and
create-if-absent is what lets a repair run leave an operator's edited file alone. The temp
file is a sibling of its destination, never `$TMPDIR`, because neither a hard link nor an
atomic rename crosses a filesystem. Keep a `mv` fallback for the filesystems that have no
hard links at all; it is only reached where `ln` cannot work.

The mode is the part that bites silently. `mktemp` creates its file 0600, and neither `cp`
onto an already-existing file nor a `> "$tmp"` redirection widens that, so every shipped
file lands 0600 instead of the 0644 a direct `cp` would have produced. `chmod +rw "$tmp"`
fixes it correctly: a symbolic mode with no "who" is masked by the umask, which is exactly
the rule a freshly created file obeys, so an operator running under `umask 077` still gets
0600 and one under `umask 022` gets 0644. A hardcoded `chmod 644` would override the
operator's umask instead of honouring it.

<!-- kk:related:start -->
# Related

- Related: [practice-check-then-act-cp-is-not-a-create-if-absent](/practice-check-then-act-cp-is-not-a-create-if-absent.md)
<!-- kk:related:end -->
