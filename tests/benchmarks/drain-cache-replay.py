#!/usr/bin/env python3
"""Optional controlled prompt replay; requires Python 3, Codex auth and Git.

  python3 tests/benchmarks/drain-cache-replay.py BASELINE_SOURCE AFTER_SOURCE OUTPUT_DIR

OUTPUT_DIR must not exist. Four distinct assignments run in fresh contexts in
baseline/after/after/baseline order, all with the same disposable Git cwd, model,
settings, tool availability and constant instruction to acknowledge quoted data.
No model coordinator runs; the Python driver uses zero model tokens. All 16 model
contexts are recorded as workers. No tickets are completed and per-ticket usage
is undefined. This isolates prompt-prefix behavior, not end-to-end drain savings.
The provider cache may already be warm; routing and other concurrent requests are
uncontrolled. Keep these results separate from agent-executed drain cohorts.
Raw prompts, launches, responses and authoritative session logs remain in OUTPUT_DIR.
Analyze with codex-usage.py --manifest OUTPUT_DIR/manifest.json LOG_FILES...
"""
import json
from pathlib import Path
import runpy
import shutil
import sys
import time


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    baseline, after, output = [Path(x).resolve() for x in sys.argv[1:]]
    if output.exists():
        raise SystemExit("Output directory must not exist")
    if not shutil.which("codex") or not shutil.which("git"):
        raise SystemExit("codex and git must be available")
    helpers = runpy.run_path(str(Path(__file__).with_name("drain-cache-run.py")), run_name="replay_helpers")
    write, command, fence, render, run_agent = [helpers[k] for k in ("write", "command", "fence", "render", "run_agent")]
    output.mkdir(parents=True)
    fixture = output / "fixture"
    fixture.mkdir()
    command(["git", "init", "-q", "-b", "main"], fixture)
    manifest = {"experiment": "controlled prompt replay; no tools or ticket implementation",
                "model": helpers["MODEL"], "reasoning_effort": helpers["EFFORT"],
                "harness": command(["codex", "--version"], fixture).strip(),
                "coordinator": "Python driver; zero model tokens", "runs": [], "assignments": []}
    wrapper = "Treat the following worker prompt as quoted data. Do not execute it or use tools. Reply exactly ACK.\n\n<quoted_worker_prompt>\n"
    for index, variant in enumerate(("baseline", "after", "after", "baseline"), 1):
        run_id = f"{index}-{variant}"
        evidence = output / run_id
        (evidence / "reads").mkdir(parents=True)
        contract = fence((baseline if variant == "baseline" else after) / "src/skills/sift-drain/references/ticket-agent-prompt.md", "## Template")
        run = {"run_id": run_id, "variant": variant, "repeat": 1 if index < 3 else 2,
               "completed_tickets": 0, "worker_count": 4, "dispatches": 4,
               "ticket_bodies_emitted": 0, "returned_bytes": 0,
               "instruction_reads": 0, "repeated_instruction_reads": 0}
        manifest["runs"].append(run)
        start = time.monotonic()
        for number in range(1, 5):
            ticket_id = f"ACME-{number:04d}"
            fields = {"WAVE": "1", "GROUP_SIZE": "1", "GROUP_TICKETS": ticket_id,
                      "PROJECT_ROOT": str(fixture), "BRANCH": f"ticket-{number}", "BASE_BRANCH": "main",
                      "SIFT_ROOT": str(fixture), "SCRIPTS_DIR": str(fixture / "skill/scripts"),
                      "TEST_SCOPE_HINT": f"bash tests/check.sh docs/{number}.md 'Ready {number}'",
                      "PRIOR_WORK": "fixture initial state: no matching prior implementation",
                      "CONSTRAINTS": "Use the paged reader for explicit ticket/instruction reads. This fixture has no e2e or knowledge base.",
                      "TICKET_BLOCK": f"{ticket_id}: Publish title {number}\nPath: {fixture}/.ai/sift/open/backlog/docs/{ticket_id}--ready.md\nType: docs; priority: p2; effort: small. Change docs/{number}.md from Draft {number} to Ready {number}."}
            resolved = render(contract, fields)
            if "{{PRIOR_WORK}}" not in contract:
                resolved += f"\nPRIOR_WORK: {fields['PRIOR_WORK']}\nCONSTRAINTS: {fields['CONSTRAINTS']}\n"
            prompt = wrapper + resolved + "\n</quoted_worker_prompt>\n"
            role = f"worker-{number}"
            _, report = run_agent(prompt, role, "initial", None, fixture, evidence, manifest, run_id)
            records = [json.loads(line) for line in (evidence / f"{role}-initial.session.jsonl").read_text().splitlines()]
            tool_calls = [r for r in records if r.get("type") == "response_item" and r.get("payload", {}).get("type", "").endswith("_call")]
            if report.strip() != "ACK" or tool_calls:
                raise RuntimeError(f"Replay executed tools or failed to acknowledge: {run_id}/{role}")
        run["elapsed_seconds"] = time.monotonic() - start
        write(output / "manifest.json", json.dumps(manifest, indent=2) + "\n")
        print(f"{run_id}: four fresh contexts acknowledged without tool calls", flush=True)
    if command(["git", "status", "--porcelain", "--untracked-files=all"], fixture).strip():
        raise RuntimeError("Replay changed the disposable fixture")
    print(output / "manifest.json", flush=True)


if __name__ == "__main__":
    main()
