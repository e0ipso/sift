#!/usr/bin/env python3
"""Optional live Codex experiment; requires python3, codex, authentication and git.

Run: python3 tests/benchmarks/drain-cache-run.py BASELINE_SOURCE AFTER_SOURCE OUTPUT_DIR
Creates disposable repositories only. OUTPUT_DIR must not exist. Runs baseline, after,
after, baseline with one coordinator and two retained workers, four ticket sittings each.
This is an agent-executed fixture with scripted dispatch boundaries, not an autonomous
sift-drain benchmark. No API service, cache configuration, or token estimation is used.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

MODEL = "gpt-6-astra"
EFFORT = "medium"


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def command(args, cwd, env=None):
    return subprocess.check_output([str(x) for x in args], cwd=cwd, env=env, stderr=subprocess.STDOUT).decode()


def fence(path, heading):
    section = path.read_text().split(heading + "\n", 1)[1]
    return section.split("```\n", 1)[1].split("\n```", 1)[0] + "\n"


def render(template, fields):
    return re.sub(r"\{\{(\w+)\}\}", lambda m: fields[m[1]], template)


def fixture(source, root, evidence):
    root.mkdir()
    project = root / "project"
    project.mkdir()
    scripts = root / "skill" / "scripts"
    shutil.copytree(source / "src/skills/sift-drain", root / "skill")
    shutil.copytree(source / "src/skills/sift-init", root / "sift-init")
    # Identical instrumentation on both variants; bytes sent to the model are unchanged.
    reader = scripts / "read-context.sh"
    reader.rename(scripts / "read-context-real.sh")
    write(reader, '''#!/usr/bin/env bash
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
log=$(mktemp "$SIFT_BENCH_READS/read.XXXXXX")
"$here/read-context-real.sh" "$@" > "$log"
printf '%s\\t%s\\t%s\\n' "$1" "$2" "${3:-1}" > "$log.args"
cat "$log"
''')
    reader.chmod(0o755)
    sift = project / ".ai/sift"
    for folder in ["open/backlog/docs", "archive", "config", "schemas", "scripts"]:
        (sift / folder).mkdir(parents=True, exist_ok=True)
    shutil.copy(source / "README.md", sift / "README.md")
    shutil.copy(source / "src/operations/sift.sh", sift / "scripts/sift.sh")
    write(sift / "config/config.yaml", "prefix: ACME\n")
    write(sift / "MILESTONES.md", "# Milestones\n\n## backlog\n")
    write(project / ".gitignore", ".ai/sift/\n")
    write(project / "AGENTS.md", """# Fixture instructions
This is a disposable documentation project. Follow the supplied worker contract.
Use the supplied read-context.sh for explicit instruction and ticket reads so the experiment
can count returned pages. Load docs/AGENTS.md when editing docs. No knowledge base exists.
For a ticket, verify with bash tests/check.sh docs/NUMBER.md 'Ready NUMBER'.
Authoritative lint is git diff --check; shell static analysis is bash -n tests/check.sh tests/run.sh.
Full verification at close is bash tests/run.sh, git diff --check, and the same bash -n command.
There is no e2e layer and no knowledge-capture skill applicable to this fixture.
Keep one implementation commit per ticket. No push. Never change tests to pass a ticket.
""")
    write(project / "docs/AGENTS.md", "# Documentation scope\nEach numbered file is one plain title line ending in a newline.\n")
    write(project / "tests/check.sh", '#!/usr/bin/env bash\nset -eu\n[ "$(cat "$1")" = "$2" ]\nprintf "1 check passed\\n"\n')
    write(project / "tests/run.sh", '#!/usr/bin/env bash\nset -eu\nfor n in 1 2 3 4; do bash tests/check.sh "docs/$n.md" "Ready $n"; done\nprintf "4 checks passed\\n"\n')
    for n in range(1, 5):
        write(project / f"docs/{n}.md", f"Draft {n}\n")
        dependency = f"depends_on: [ACME-{n-2:04d}]\n" if n > 2 else ""
        write(sift / f"open/backlog/docs/ACME-{n:04d}--ready.md", f"""---
id: ACME-{n:04d}
title: Publish title {n}
status: open
type: docs
priority: p2
effort: small
milestone: backlog
wave: 1
source: fixture
created: 2026-09-09
updated: 2026-09-09
{dependency}---

## Problem
The document still has a draft title.

## Evidence
- `docs/{n}.md:1` reads Draft {n}.

## Direction
Replace the one line in docs/{n}.md with Ready {n} and keep a final newline.

## Acceptance criteria
- `bash tests/check.sh docs/{n}.md 'Ready {n}'` exits 0.
- Other numbered documents are unchanged by this ticket.
""")
    command(["git", "init", "-q", "-b", "main"], project)
    command(["git", "config", "user.name", "Fixture"], project)
    command(["git", "config", "user.email", "fixture@example.invalid"], project)
    command(["git", "add", "AGENTS.md", "docs", "tests", ".gitignore"], project)
    env = dict(os.environ, GIT_AUTHOR_DATE="2026-09-09T00:00:00Z", GIT_COMMITTER_DATE="2026-09-09T00:00:00Z")
    command(["git", "commit", "-qm", "docs: initialize fixture"], project, env)
    (evidence / "reads").mkdir()
    return project, scripts


def run_agent(prompt, role, phase, thread, cwd, evidence, manifest, run_id):
    name = f"{role}-{phase}"
    write(evidence / f"{name}.prompt.txt", prompt)
    args = ["codex", "exec"] + (["resume", thread] if thread else ["-C", str(cwd)])
    args += ["--ignore-user-config", "--ignore-rules", "--json", "--dangerously-bypass-approvals-and-sandbox",
             "-m", MODEL, "-c", f'model_reasoning_effort="{EFFORT}"',
             "-o", str(evidence / f"{name}.report.txt"), "-"]
    env = dict(os.environ, SIFT_BENCH_READS=str(evidence / "reads"))
    reads_before = set((evidence / "reads").glob("*.args"))
    start = time.monotonic()
    with (evidence / f"{name}.stdout.jsonl").open("w") as out, (evidence / f"{name}.stderr.log").open("w") as err:
        result = subprocess.run(args, input=prompt, text=True, stdout=out, stderr=err, cwd=cwd, env=env, timeout=600)
    write(evidence / f"{name}.launch.json", json.dumps({"command": args, "exit_code": result.returncode,
          "elapsed_seconds": time.monotonic() - start}, indent=2) + "\n")
    write(evidence / f"{name}.reads.json", json.dumps([str(p.relative_to(evidence)) for p in sorted(set((evidence / "reads").glob("*.args")) - reads_before)], indent=2) + "\n")
    events = [json.loads(x) for x in (evidence / f"{name}.stdout.jsonl").read_text().splitlines()]
    thread = next((x["thread_id"] for x in events if x["type"] == "thread.started"), thread)
    if not thread:
        raise RuntimeError(f"No thread ID in {name}")
    # Session records are authoritative. Preserve the complete thread file after each dispatch.
    logs = list((Path.home() / ".codex/sessions").rglob(f"*{thread}.jsonl"))
    if not logs:
        raise RuntimeError(f"No persistent usage log for {thread}")
    session = logs[0]
    records = [json.loads(x) for x in session.read_text().splitlines()]
    usage = [r for r in records if r.get("type") == "token_usage_record"]
    if not usage:
        raise RuntimeError(f"No per-response usage for {thread}")
    turn = usage[-1]["payload"]["turn_id"]
    shutil.copy(session, evidence / f"{name}.session.jsonl")
    manifest["assignments"].append({"thread_id": thread, "turn_id": turn, "run_id": run_id,
          "role": role, "phase": phase, "worker_reused": bool(phase == "subsequent" and role.startswith("worker"))})
    write(evidence.parent / "manifest.json", json.dumps(manifest, indent=2) + "\n")
    if result.returncode:
        raise RuntimeError(f"Agent failed: {name}, inspect {evidence}")
    print(f"{run_id} {name} finished", flush=True)
    return thread, (evidence / f"{name}.report.txt").read_text()


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    baseline, after, output = [Path(x).resolve() for x in sys.argv[1:]]
    if output.exists():
        raise SystemExit("Output directory must not exist")
    if not shutil.which("codex"):
        raise SystemExit("codex is unavailable")
    output.mkdir(parents=True)
    # A stable absolute fixture path across ABBA avoids a variant-specific path in system context.
    active = output / "active"
    manifest = {"model": MODEL, "reasoning_effort": EFFORT, "harness": command(["codex", "--version"], output).strip(),
                "experiment": "agent-executed fixture; scripted dispatch boundaries", "runs": [], "assignments": []}
    for index, variant in enumerate(["baseline", "after", "after", "baseline"], 1):
        run_id = f"{index}-{variant}"
        evidence = output / run_id
        evidence.mkdir()
        project, scripts = fixture(baseline if variant == "baseline" else after, active, evidence)
        start = time.monotonic()
        run = {"run_id": run_id, "variant": variant, "repeat": 1 if index < 3 else 2,
               "completed_tickets": 0, "worker_count": 2, "dispatches": 4}
        manifest["runs"].append(run)
        write(output / "manifest.json", json.dumps(manifest, indent=2) + "\n")
        contract = fence(active / "skill/references/ticket-agent-prompt.md", "## Template")
        reuse = fence(active / "skill/references/ticket-agent-prompt.md", "## Reuse a worker")
        coordinator_prompt = f"""Coordinate this disposable Sift fixture in {project}. The external experiment driver owns
worker launch, branch/worktree preparation and dispatch stamps. Do not spawn workers yourself.
All work and searches stay inside {active}. Run {active}/sift-init/scripts/sift-gate.sh first.
The fixture is already initialized. Do not search outside this disposable tree.
Read {active}/skill/SKILL.md and its intake/run-management sections using
{scripts}/read-context.sh. Retain a reconciled live snapshot and ticket context; preserve
priority, dependencies and ownership. Read current tickets with that reader, check prior work,
and confirm ACME-0001 and ACME-0002 are ready in disjoint scopes; ACME-0003 and ACME-0004
must wait for their respective dependencies. Do not implement, archive, or preload wave gates.
Return READY with the ready IDs and any blockers, then wait for the driver to return reports.
"""
        coordinator, readiness = run_agent(coordinator_prompt, "coordinator", "initial", None, project, evidence, manifest, run_id)
        if "READY" not in readiness:
            raise RuntimeError("Coordinator did not confirm initial readiness")
        workers = [None, None]
        for sitting_round in range(2):
            reports = []
            for slot in range(2):
                n = sitting_round * 2 + slot + 1
                ticket_id = f"ACME-{n:04d}"
                branch = f"ticket-{n}"
                worktree = active / f"worktree-{n}"
                env = dict(os.environ, SIFT_ROOT=str(project))
                write(evidence / f"prepare-{n}.log", command([scripts / "prepare-worktree.sh", "main", branch, worktree], project))
                write(evidence / f"dispatch-{n}.log", command([scripts / "drain-log.sh", "dispatch", ticket_id], project, env))
                fields = {"WAVE": "1", "GROUP_SIZE": "1", "GROUP_TICKETS": ticket_id,
                    "PROJECT_ROOT": str(worktree), "BRANCH": branch, "BASE_BRANCH": "main", "SIFT_ROOT": str(project),
                    "SCRIPTS_DIR": str(scripts), "TEST_SCOPE_HINT": f"bash tests/check.sh docs/{n}.md 'Ready {n}'",
                    "PRIOR_WORK": f"{command(['git','rev-parse','HEAD'],project).strip()}: no matching prior implementation",
                    "CONSTRAINTS": "Use the paged reader for explicit ticket/instruction reads. This fixture has no e2e or knowledge base.",
                    "TICKET_BLOCK": f"{ticket_id}: Publish title {n}\nPath: {project}/.ai/sift/open/backlog/docs/{ticket_id}--ready.md\nType: docs; priority: p2; effort: small. Change docs/{n}.md from Draft {n} to Ready {n}."}
                rendered = render(contract, fields)
                if workers[slot]:
                    if "\nAssignment:\n" in rendered:
                        inputs = "Assignment:\n" + rendered.split("\nAssignment:\n", 1)[1]
                    else:
                        inputs = "\n".join(f"{k}: {v}" for k, v in fields.items())
                    rendered = render(reuse, {"SITTING_INPUTS": inputs})
                else:
                    # Baseline already accepts prior-work and constraints outside its template.
                    if "{{PRIOR_WORK}}" not in contract:
                        rendered += f"\nPRIOR_WORK: {fields['PRIOR_WORK']}\nCONSTRAINTS: {fields['CONSTRAINTS']}\n"
                workers[slot], report = run_agent(rendered, f"worker-{slot+1}", "initial" if sitting_round == 0 else "subsequent",
                           workers[slot], worktree, evidence, manifest, run_id)
                if not re.search(r"status:.*done|ACME-\d{4}.*done", report):
                    raise RuntimeError(f"Worker did not complete {ticket_id}")
                reports.append(report)
            close = sitting_round == 1
            prompt = f"""Worker reports follow. Handle tamper and missing evidence first. Stamp returns, land each
finished ticket's commit separately, archive it with resolution/status/updated using the live
shared tracker at {project}/.ai/sift, and run {scripts}/ticket-check.sh.
Do not implement product changes. Refresh the live wave snapshot and reconcile tickets before
checking readiness of the remaining dependency edges. Use {scripts}/read-context.sh for reads.
""" + ("All four tickets should now be complete. Load only needed wave-gate sections. There is no e2e layer, no deferred criteria, no knowledge candidates. No authoring agents are needed. Run every full verification command from AGENTS.md on the integrated tree, preserve logs and report exact results. Return CLOSED only when verification and tracker checks pass.\n" if close else "Confirm ACME-0003 and ACME-0004 are ready; return READY and wait.\n") + "\n".join(reports)
            coordinator, readiness = run_agent(prompt, "coordinator", "close" if close else "subsequent", coordinator, project, evidence, manifest, run_id)
            if ("CLOSED" if close else "READY") not in readiness:
                raise RuntimeError("Coordinator did not confirm landing/readiness")
        env = dict(os.environ, SIFT_ROOT=str(project))
        write(evidence / "acceptance.log", command(["bash", "tests/run.sh"], project))
        write(evidence / "tracker-check.log", command([scripts / "ticket-check.sh"], project, env))
        write(evidence / "commits.log", command(["git", "log", "--oneline", "--name-only"], project))
        run["completed_tickets"] = len(list((project / ".ai/sift/archive").rglob("ACME-*.md")))
        if run["completed_tickets"] != 4:
            raise RuntimeError("Four tickets were not archived")
        run["elapsed_seconds"] = time.monotonic() - start
        write(output / "manifest.json", json.dumps(manifest, indent=2) + "\n")
        # Preserve every fixture, including its ignored tracker and git history. No clean/reset.
        active.rename(evidence / "fixture")
        print(f"{run_id} verified four tickets", flush=True)
    print(output / "manifest.json")


if __name__ == "__main__":
    main()
