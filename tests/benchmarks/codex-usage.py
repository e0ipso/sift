#!/usr/bin/env python3
"""Offline accounting for explicit Codex session logs, using Python 3 stdlib only.

  python3 tests/benchmarks/codex-usage.py session.jsonl mirror.jsonl > usage.json
  python3 tests/benchmarks/codex-usage.py --manifest manifest.json session.jsonl

Manifest example, with one entry for EVERY coordinator and worker turn:
{"runs": [{"run_id": "before-1", "variant": "before", "repeat": 1,
           "completed_tickets": 2, "elapsed_seconds": 12.5}],
 "assignments": [{"thread_id": "thread", "turn_id": "turn",
                  "run_id": "before-1", "role": "coordinator",
                  "phase": "initial", "worker_reused": false}]}

Phases are initial/subsequent/close; roles are coordinator/worker or worker-N. Worker reuse must be
recorded by the runner. Optional run metrics are ticket_bodies_emitted,
returned_bytes, instruction_reads and repeated_instruction_reads. Missing metrics
remain null. Completed tickets must come from verified fixture outcomes, not the
model's claim. Replay runs should record zero completed tickets. Elapsed seconds
come from runner wall-clock timing, not the span between usage records.

Only token_usage_record.payload.usage is counted, once per response_id. Mirrored
token_count and cumulative turn/thread counters are ignored. Conflicting response
IDs or malformed counters fail. Missing counters propagate null, never zero.
reasoning_output_tokens is reported separately as a subset of output_tokens;
total usage is input+output. Cache writes are separately reported, not added.
A manifest selects exact thread/turn pairs and fails if any expected turn has no
usage. Supply all worker files: this tool cannot discover an omitted worker.
Compaction observations retain locations from the supplied logs; absence proves
only that no recognized compaction event was present in those files.
This collects neither provider requests nor ticket/read metrics. Do not mix
providers or model/settings cohorts in one invocation.
"""

import argparse
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

COUNTERS = ("input_tokens", "cached_input_tokens", "cache_write_input_tokens",
            "output_tokens", "reasoning_output_tokens")
IDS = ("response_id", "thread_id", "turn_id", "root_turn_id", "session_id")
METRICS = ("completed_tickets", "elapsed_seconds", "ticket_bodies_emitted",
           "returned_bytes", "instruction_reads", "repeated_instruction_reads")


def identifier(value, label):
    if not isinstance(value, str) or not value or any(c.isspace() or not c.isprintable() for c in value):
        raise ValueError(f"{label} must be a nonempty identifier without whitespace")
    return value


def counter(value, label, fractional=False):
    kinds = (int, float) if fractional else (int,)
    if type(value) not in kinds or value < 0 or (type(value) is float and not math.isfinite(value)):
        raise ValueError(f"{label} must be a finite nonnegative {'number' if fractional else 'integer'}")
    return value


def sum_known(values):
    values = list(values)
    return sum(values) if values and all(v is not None for v in values) else None


def ratio(numerator, denominator):
    return numerator / denominator if numerator is not None and denominator else None


def aggregate(rows, completed=None):
    totals = {key: sum_known(r["usage"][key] for r in rows) for key in COUNTERS}
    inp, cached, out = (totals[k] for k in ("input_tokens", "cached_input_tokens", "output_tokens"))
    totals.update(responses=len(rows),
                  uncached_input_tokens=inp-cached if inp is not None and cached is not None else None,
                  total_tokens=inp+out if inp is not None and out is not None else None,
                  cached_token_share=ratio(cached, inp))
    totals["uncached_input_per_completed_ticket"] = ratio(totals["uncached_input_tokens"], completed)
    totals["total_usage_per_completed_ticket"] = ratio(totals["total_tokens"], completed)
    totals["missing_counter_responses"] = {
        key: sum(r["usage"][key] is None for r in rows) for key in COUNTERS}
    return totals


def read_manifest(path):
    if path is None:
        return {}, {}
    data = json.loads(Path(path).read_text())
    runs, assignments = {}, {}
    if not isinstance(data, dict) or not isinstance(data.get("runs"), list) or not isinstance(data.get("assignments"), list):
        raise ValueError("manifest requires runs and assignments arrays")
    for run in data["runs"]:
        run = dict(run)
        run_id = identifier(run.get("run_id"), "run_id")
        identifier(run.get("variant"), "variant")
        counter(run.get("repeat"), "repeat")
        if run_id in runs:
            raise ValueError(f"duplicate run_id {run_id}")
        for key in METRICS:
            value = run.get(key)
            run[key] = None if value is None else counter(value, key, key == "elapsed_seconds")
        runs[run_id] = run
    for assignment in data["assignments"]:
        assignment = dict(assignment)
        key = tuple(identifier(assignment.get(k), k) for k in ("thread_id", "turn_id"))
        if key in assignments or assignment.get("run_id") not in runs:
            raise ValueError(f"duplicate assignment or unknown run for {key}")
        if not re.fullmatch(r"coordinator|worker(?:-[0-9]+)?", str(assignment.get("role"))) or assignment.get("phase") not in ("initial", "subsequent", "close"):
            raise ValueError(f"invalid role or phase for {key}")
        if type(assignment.get("worker_reused")) is not bool:
            raise ValueError(f"worker_reused must be boolean for {key}")
        assignments[key] = assignment
    if not runs or not assignments:
        raise ValueError("manifest runs and assignments must not be empty")
    if set(runs) != {a["run_id"] for a in assignments.values()}:
        raise ValueError("each run must have at least one expected assignment")
    return runs, assignments


def collect(paths, assignments):
    responses, compactions, ignored = {}, [], 0
    for path in paths:
        path = Path(path).resolve()
        with path.open() as source:
            for line_number, line in enumerate(source, 1):
                if not line.strip():
                    continue
                location = {"file": str(path), "line": line_number}
                try:
                    record = json.loads(line)
                    if not isinstance(record, dict):
                        raise ValueError("record must be an object")
                    payload = record.get("payload", {})
                    kind = record.get("type")
                    event = payload.get("type") if isinstance(payload, dict) else None
                    if kind == "compacted" or (kind == "event_msg" and event in ("context_compacted", "compaction_completed")):
                        compactions.append(dict(location, timestamp=record.get("timestamp"), type=kind,
                                                event=event, thread_id=payload.get("thread_id"),
                                                turn_id=payload.get("turn_id")))
                    if kind != "token_usage_record":
                        ignored += 1
                        continue
                    if not isinstance(payload, dict) or not isinstance(payload.get("usage"), dict):
                        raise ValueError("token_usage_record requires payload.usage object")
                    ids = {key: identifier(payload.get(key), key) for key in IDS}
                    usage = {key: None if payload["usage"].get(key) is None else counter(payload["usage"][key], key)
                             for key in COUNTERS}
                    for child, parent in (("cached_input_tokens", "input_tokens"), ("reasoning_output_tokens", "output_tokens")):
                        if usage[child] is not None and usage[parent] is not None and usage[child] > usage[parent]:
                            raise ValueError(f"{child} exceeds {parent}")
                    reported_total = payload["usage"].get("total_tokens")
                    if reported_total is not None:
                        counter(reported_total, "total_tokens")
                        if usage["input_tokens"] is not None and usage["output_tokens"] is not None and reported_total != usage["input_tokens"] + usage["output_tokens"]:
                            raise ValueError("total_tokens differs from input_tokens + output_tokens")
                    row = dict(ids, usage=usage)
                    response_id = ids["response_id"]
                    if response_id in responses:
                        prior = responses[response_id]
                        if any(prior[key] != row[key] for key in (*IDS, "usage")) or prior["reported_total_tokens"] != reported_total:
                            raise ValueError(f"conflicting duplicate response_id {response_id}")
                        prior["sources"].append(location)
                    else:
                        row.update(timestamp=record.get("timestamp"), sources=[location], reported_total_tokens=reported_total)
                        responses[response_id] = row
                except (ValueError, TypeError) as error:
                    raise ValueError(f"{path}:{line_number}: {error}") from error
    selected = []
    for row in responses.values():
        key = (row["thread_id"], row["turn_id"])
        if assignments and key not in assignments:
            continue
        if assignments:
            row["assignment"] = assignments[key]
        selected.append(row)
    matched = {(r["thread_id"], r["turn_id"]) for r in selected}
    if assignments.keys() - matched:
        raise ValueError(f"usage unavailable for expected assignments: {sorted(assignments.keys() - matched)}")
    if not selected:
        raise ValueError("usage unavailable: no selected token_usage_record responses")
    first_responses = {}
    for row in sorted(selected, key=lambda r: (r["timestamp"] or "", r["response_id"])):
        key = (row["thread_id"], row["turn_id"])
        row["request_phase"] = "subsequent" if key in first_responses else "initial"
        first_responses[key] = row["response_id"]
    return selected, {"ignored_non_usage_records": ignored,
                      "excluded_unique_responses": len(responses)-len(selected),
                      "compaction_observations": compactions}


def summarize(rows, runs):
    result = {"aggregate": aggregate(rows, sum_known(r["completed_tickets"] for r in runs.values())),
              "runs": [], "variants": []}
    for run_id, run in runs.items():
        group = [r for r in rows if r["assignment"]["run_id"] == run_id]
        breakdown = defaultdict(list)
        request_breakdown = defaultdict(list)
        for row in group:
            a = row["assignment"]
            breakdown[(a["role"], a["phase"])].append(row)
            request_breakdown[("worker" if a["role"].startswith("worker") else "coordinator",
                               "subsequent" if a["phase"] == "close" else a["phase"], row["request_phase"])].append(row)
        result["runs"].append(dict(run, usage=aggregate(group, run["completed_tickets"]),
                                   by_role_phase=[dict(role=k[0], phase=k[1], usage=aggregate(v))
                                                  for k, v in sorted(breakdown.items())],
                                   by_request_phase=[dict(role=k[0], dispatch_phase=k[1], request_phase=k[2], usage=aggregate(v))
                                                     for k, v in sorted(request_breakdown.items())]))
    for variant in sorted({r["variant"] for r in runs.values()}):
        variant_runs = [r for r in runs.values() if r["variant"] == variant]
        metrics = {key: sum_known(r[key] for r in variant_runs) for key in METRICS}
        group = [r for r in rows if runs[r["assignment"]["run_id"]]["variant"] == variant]
        result["variants"].append(dict(variant=variant, run_count=len(variant_runs), **metrics,
                                       usage=aggregate(group, metrics["completed_tickets"])))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", help="explicit run and thread/turn assignments JSON")
    parser.add_argument("logs", nargs="+", help="Codex session JSONL files, including all workers")
    args = parser.parse_args()
    try:
        runs, assignments = read_manifest(args.manifest)
        rows, observations = collect(args.logs, assignments)
        result = dict(status="available", accounting="deduplicated per-response payload.usage",
                      **summarize(rows, runs), **observations, responses=rows)
        print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(json.dumps({"status": "unavailable", "error": str(error)}), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
