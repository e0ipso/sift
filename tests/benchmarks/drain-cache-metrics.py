#!/usr/bin/env python3
"""Enrich an experiment manifest with offline read and returned-text measurements.

  python3 tests/benchmarks/drain-cache-metrics.py EXPERIMENT_DIR > metrics-manifest.json
  python3 tests/benchmarks/codex-usage.py --manifest metrics-manifest.json LOG_FILES...

EXPERIMENT_DIR contains manifest.json and RUN_ID/{*.session.jsonl,*.reads.json,reads/}.
Reads JSON files list the instrumented *.args paths created during that launch.
Only canonical response_item function_call_output/custom_tool_call_output records
count returned UTF-8 text bytes. Mirrored event_msg outputs and repeated session
snapshots do not count twice. These are visible text bytes, not wire or token bytes.
Non-text output makes returned_bytes unknown. Instrumented page bytes are also
reported separately. Direct reads that bypass read-context.sh are outside the read
counts. A ticket-body emission means a ticket read beginning at page 1; continuation
pages count separately. Repeated instruction reads mean the same normalized path,
heading and page read again in the same retained thread. Changed instruction content
still counts as a reread. Other relative/absolute aliases are not resolved. Worktree numbers normalize to the shared project path.
Missing launch read attribution makes repeated_instruction_reads unknown, not zero.
No provider calls, fixture writes or source-tree writes are performed.
"""
import json
from pathlib import Path
import re
import sys


def text_bytes(output):
    if isinstance(output, str):
        return len(output.encode("utf-8"))
    if isinstance(output, list) and all(isinstance(x, dict) and x.get("type") in ("text", "input_text")
                                        and isinstance(x.get("text"), str) for x in output):
        return sum(len(x["text"].encode("utf-8")) for x in output)
    return None


def instruction_path(path):
    normalized = re.sub(r"/worktree-[0-9]+/", "/project/", path)
    if Path(path).name in ("AGENTS.md", "SKILL.md") or "/skill/references/" in path or (path == ".ai/sift/README.md" or path.endswith("/.ai/sift/README.md")):
        return normalized
    return None


def measure(run_dir, assignments):
    outputs, compactions = {}, {}
    by_turn = {(a["thread_id"], a["turn_id"]): a for a in assignments}
    for source in sorted(run_dir.glob("*.session.jsonl")):
        thread, turn = None, None
        for number, line in enumerate(source.open(), 1):
            record = json.loads(line)
            payload = record.get("payload", {})
            kind = record.get("type")
            if kind == "session_meta":
                thread = payload.get("id")
            elif kind == "turn_context":
                turn = payload.get("turn_id")
            elif kind == "token_usage_record":
                thread, turn = payload["thread_id"], payload["turn_id"]
            location = {"file": str(source), "line": number}
            if kind == "compacted" or (kind == "event_msg" and payload.get("type") in ("context_compacted", "compaction_completed")):
                key = (thread, record.get("timestamp"), record.get("ordinal"))
                compactions.setdefault(key, {"thread_id": thread, "turn_id": turn, "sources": []})["sources"].append(location)
            if kind != "response_item" or payload.get("type") not in ("function_call_output", "custom_tool_call_output"):
                continue
            if not thread or not turn or not payload.get("call_id"):
                raise ValueError(f"cannot attribute canonical tool output at {source}:{number}")
            assignment = by_turn.get((thread, turn))
            if assignment is None:
                raise ValueError(f"tool output belongs to unmapped turn {thread}/{turn}")
            key = (thread, payload["call_id"])
            output = payload.get("output")
            if key in outputs:
                if outputs[key]["output"] != output or outputs[key]["turn_id"] != turn:
                    raise ValueError(f"conflicting canonical tool output {key}")
                outputs[key]["sources"].append(location)
            else:
                outputs[key] = {"thread_id": thread, "turn_id": turn, "call_id": payload["call_id"],
                                "role": assignment["role"], "phase": assignment["phase"],
                                "returned_bytes": text_bytes(output), "output": output, "sources": [location]}
    # Assignment order is launch order, so repeated reads cross retained dispatches.
    reads, seen, attributed = [], set(), set()
    missing_attribution = False
    for assignment in assignments:
        launch = f"{assignment['role']}-{assignment['phase']}"
        index = run_dir / f"{launch}.reads.json"
        if not index.is_file():
            missing_attribution = True
            continue
        for relative in json.loads(index.read_text()):
            args = (run_dir / relative).resolve()
            if (run_dir / "reads").resolve() not in args.parents or not args.name.endswith(".args"):
                raise ValueError(f"read index path outside instrumentation: {relative}")
            if args in attributed:
                raise ValueError(f"read attributed to multiple launches: {args}")
            attributed.add(args)
            fields = args.read_text().rstrip("\n").split("\t")
            if len(fields) != 3 or not fields[2].isdigit() or int(fields[2]) < 1:
                raise ValueError(f"invalid read arguments: {args}")
            target, heading, page = fields
            payload_file = args.with_suffix("")
            instruction = instruction_path(target)
            key = (assignment["thread_id"], instruction, heading, page)
            repeated = bool(instruction and key in seen)
            if instruction:
                seen.add(key)
            reads.append({"args_file": str(args), "payload_file": str(payload_file),
                          "target": target, "heading": heading, "page": int(page),
                          "role": assignment["role"], "phase": assignment["phase"],
                          "thread_id": assignment["thread_id"],
                          "bytes": payload_file.stat().st_size, "instruction": bool(instruction),
                          "repeated_instruction": repeated,
                          "ticket": bool(re.search(r"(?:^|/)\.ai/sift/(?:open|archive)/.*[^/]+-[0-9]{4,}[^/]*\.md$", target))})
    all_args = {p.resolve() for p in (run_dir / "reads").glob("*.args")}
    if all_args - attributed:
        missing_attribution = True
    # Even unattributed reads have reliable total bytes and target/page classifications.
    for args in sorted(all_args - attributed):
        target, heading, page = args.read_text().rstrip("\n").split("\t")
        reads.append({"args_file": str(args), "payload_file": str(args.with_suffix("")),
                      "target": target, "heading": heading, "page": int(page),
                      "role": None, "phase": None, "thread_id": None,
                      "bytes": args.with_suffix("").stat().st_size,
                      "instruction": bool(instruction_path(target)), "repeated_instruction": None,
                      "ticket": bool(re.search(r"(?:^|/)\.ai/sift/(?:open|archive)/.*[^/]+-[0-9]{4,}[^/]*\.md$", target))})
    output_rows = [{k: v for k, v in row.items() if k != "output"} for row in outputs.values()]
    sizes = [r["returned_bytes"] for r in output_rows]
    return {"returned_bytes": sum(sizes) if sizes and None not in sizes else None,
            "ticket_bodies_emitted": sum(r["ticket"] and r["page"] == 1 for r in reads),
            "instruction_reads": sum(r["instruction"] for r in reads),
            "repeated_instruction_reads": None if missing_attribution else sum(r["repeated_instruction"] for r in reads),
            "telemetry": {"instrumented_returned_bytes": sum(r["bytes"] for r in reads),
                          "ticket_body_pages": sum(r["ticket"] for r in reads),
                          "read_attribution_complete": not missing_attribution,
                          "reads": reads, "tool_outputs": output_rows,
                          "compactions": list(compactions.values())}}


def main():
    if len(sys.argv) != 2:
        raise ValueError("usage: drain-cache-metrics.py EXPERIMENT_DIR")
    root = Path(sys.argv[1]).resolve()
    manifest = json.loads((root / "manifest.json").read_text())
    for run in manifest["runs"]:
        assignments = [a for a in manifest["assignments"] if a["run_id"] == run["run_id"]]
        run.update(measure(root / run["run_id"], assignments))
    manifest["read_measurement_scope"] = "instrumented read-context.sh calls only; bypassed reads are not counted"
    manifest["returned_byte_scope"] = "canonical tool-output UTF-8 text including tool metadata; excludes messages and wire framing"
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"status": "unavailable", "error": str(error)}), file=sys.stderr)
        sys.exit(2)
