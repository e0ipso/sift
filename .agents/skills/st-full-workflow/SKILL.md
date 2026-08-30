---
name: st-full-workflow
description: Use when the user asks to run the complete end-to-end Strikethroo workflow for a work order in one shot in this repository — triggers include full workflow, end-to-end, plan and execute, do everything, run the whole strikethroo workflow. Do not use when the user wants only one stage (create a plan, generate tasks, or execute a blueprint); use the dedicated skill for that stage instead.
---

# st-full-workflow

Run the three Strikethroo stages as one uninterrupted workflow. This skill is
only the orchestrator: each stage skill owns its procedure, scripts, validation,
hooks, output contract, and failure handling.

## Input

The user's request is the work order passed to `st-create-plan`. Keep that
request intact; do not reinterpret it between stages.

## Authoritative stages

Follow these skills in this order and follow each one's `SKILL.md` completely.
Do not copy or reconstruct a stage's procedure here. The records below are read
by `tests/static/strikethroo-full-workflow.test.sh`; each target is a skill
directory and the construct after it must remain in that skill's front matter.

```text
@FULL-WORKFLOW-STAGE: .agents/skills/st-create-plan/ name: st-create-plan
@FULL-WORKFLOW-STAGE: .agents/skills/st-generate-tasks/ name: st-generate-tasks
@FULL-WORKFLOW-STAGE: .agents/skills/st-execute-blueprint/ name: st-execute-blueprint
```

The workflow contract is recorded beside the prose that applies it. The same
test pins the order, immutable plan ID, approval boundary, and failure edge.

```text
@FULL-WORKFLOW: clarify st-create-plan before-plan-id
@FULL-WORKFLOW: handoff st-create-plan st-generate-tasks numeric-plan-id no-approval
@FULL-WORKFLOW: handoff st-generate-tasks st-execute-blueprint same-numeric-plan-id no-approval
@FULL-WORKFLOW: stop blocked-or-failed report-no-fallback
```

## Workflow

### 1. Create the plan

Follow `st-create-plan` with the user's work order. Its clarification loop is
the only permitted user interaction during this full workflow: it happens
before a plan ID is allocated and is part of plan creation, not an inter-stage
approval pause. Resume that same stage when the user answers.

Plan creation succeeds only when the stage completes its own contract and
returns a numeric Plan ID. Capture that value once as `PLAN_ID`. Never allocate
an ID from this orchestrator and never infer one from paths or repository state.

### 2. Generate tasks

After plan creation succeeds, immediately follow `st-generate-tasks` with
`PLAN_ID`. Do not ask whether to continue. The task-generation stage owns all
decomposition, complexity, routing, validation, and blueprint-generation rules.

Treat task generation as successful only when the stage completes its own
contract for `PLAN_ID`. If its result names a plan ID, require it to equal
`PLAN_ID`; never replace the captured value with a later result.

### 3. Execute the blueprint

After task generation succeeds, immediately follow `st-execute-blueprint` with
the same `PLAN_ID`. Do not ask whether to execute. That stage owns readiness
validation, branch handling, task dispatch, phase gates, review, summary, and
archival.

On success, return the execution stage's result. Do not duplicate or wrap its
structured summary with a second full-workflow output format.

## Stop policy

A stage that reports blocked or failed, cannot produce its required success
result, asks for clarification after `PLAN_ID` exists, or returns a different
plan ID is not a successful handoff. Stop immediately and report the stage and
its result. Include `PLAN_ID` when one was already captured.

Never compensate for a stopped stage by allocating another plan ID, creating or
regenerating tasks, validating a blueprint, creating a branch, or executing work
inside this orchestrator. Do not invoke a later stage. The failed stage's own
contract remains the authority for any retry the user requests later.
