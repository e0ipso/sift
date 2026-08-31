# Strikethroo reference

## Documents

A work order is the user's request. Each work order has one plan that describes
the work needed to satisfy that request. Tasks are units of work within a plan.
A task may depend on another task in the same plan; its dependencies must be
complete before it can start.

## Layout

Find a plan by its front-matter ID with this command. Replace `{planId}` with
the numeric ID, such as `6`.

```shell
find .ai/strikethroo/{plans,archive} -name "plan-[0-9][0-9]*--*.md" -type f -exec grep -l "^id: \?{planId}$" {} \;
```

Plans and tasks are Markdown files with YAML front matter under
`.ai/strikethroo/`.

```text
.ai/strikethroo/
├── plans/
│   └── 01--authentication-provider/
│       ├── plan-01--authentication-provider.md
│       └── tasks/
│           ├── 01--create-project-structure.md
│           └── 02--implement-authorization.md
└── archive/
    └── 05--user-management/
        ├── plan-05--user-management.md
        └── tasks/
            └── 01--create-user-model.md
```

- Plan IDs auto-increment across active and archived plans. Front matter uses
  the numeric ID. A plan directory is named `{padded-plan-id}--{plan-slug}`,
  and its document is named `plan-{padded-plan-id}--{plan-slug}.md`.
- Task IDs are scoped to one plan, auto-increment within it, and start at `1`.
  A task file is named `{padded-task-id}--{task-slug}.md` under that plan's
  `tasks/` directory. Task dependencies refer to the numeric IDs in that plan.

## Lifecycle

Active plan directories stay under `plans/`. When `st-execute-blueprint`
successfully executes a blueprint, that skill itself moves the entire plan
directory, including its tasks and subdirectories, from `plans/` to
`archive/`. No other skill archives a plan.
