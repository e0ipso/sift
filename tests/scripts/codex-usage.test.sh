#!/usr/bin/env bash
# Offline accounting fixtures. Python is optional and no host sessions are read.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
if ! command -v python3 >/dev/null 2>&1; then
  skip "Codex per-response accounting" "python3 unavailable; optional benchmark analysis"
  summary
  exit 0
fi
COLLECTOR="$DIR/../benchmarks/codex-usage.py"
python3 - "$TMPROOT" <<'PY'
import copy
import json
import pathlib
import sys
p = pathlib.Path(sys.argv[1])
def write(name, records):
    (p / name).write_text(''.join(json.dumps(r)+'\n' for r in records))
def row(response, thread, turn, inp, cached, out):
    return {'type':'token_usage_record', 'timestamp':response, 'payload':{
        'response_id':response, 'thread_id':thread, 'turn_id':turn,
        'session_id':thread, 'root_turn_id':'root',
        'usage':{'input_tokens':inp, 'cached_input_tokens':cached,
                 'cache_write_input_tokens':0, 'output_tokens':out,
                 'reasoning_output_tokens':2, 'total_tokens':inp+out},
        'turn_token_usage':{'input_tokens':999999},
        'thread_token_usage':{'input_tokens':999999}}}
a=row('r1','coordinator','c1',100,20,10)
b=row('r2','worker','w1',900,800,20)
c=row('r3','worker','w2',200,100,30)
d=row('r4','worker','w2',300,200,40)
write('a.jsonl',[{'type':'event_msg','payload':{'type':'token_count','info':{'total_token_usage':{'input_tokens':999999}}}},a,b])
write('b.jsonl',[b,c,d,{'type':'compacted','payload':{'thread_id':'worker','turn_id':'w2'}}])
write('empty.jsonl',[{'type':'turn.completed','usage':{'input_tokens':999999}}])
missing=copy.deepcopy(a)
del missing['payload']['usage']['cached_input_tokens']
del missing['payload']['usage']['cache_write_input_tokens']
write('missing.jsonl',[missing])
write('partial.jsonl',[a,dict(missing,payload=dict(missing['payload'],response_id='r5'))])
for name, mutate in [
    ('conflict',lambda r:r['payload']['usage'].update(output_tokens=12,total_tokens=112)),
    ('negative',lambda r:r['payload']['usage'].update(input_tokens=-1)),
    ('boolean',lambda r:r['payload']['usage'].update(input_tokens=True)),
    ('fractional',lambda r:r['payload']['usage'].update(input_tokens=1.5)),
    ('cached-overflow',lambda r:r['payload']['usage'].update(cached_input_tokens=101)),
    ('reasoning-overflow',lambda r:r['payload']['usage'].update(reasoning_output_tokens=11)),
    ('total-mismatch',lambda r:r['payload']['usage'].update(total_tokens=112)),
    ('missing-id',lambda r:r['payload'].pop('response_id'))]:
    r=copy.deepcopy(a)
    mutate(r)
    write(name+'.jsonl',[r])
manifest={'runs':[{'run_id':'before-1','variant':'before','repeat':1,'completed_tickets':2,'elapsed_seconds':12.5}],
          'assignments':[dict(thread_id=t,turn_id=u,run_id='before-1',role=role,phase=phase,worker_reused=reused)
                         for t,u,role,phase,reused in [('coordinator','c1','coordinator','initial',False),('worker','w1','worker','initial',False),('worker','w2','worker','subsequent',True)]]}
(p/'manifest.json').write_text(json.dumps(manifest))
manifest['assignments'].append(dict(manifest['assignments'][0],turn_id='missing-worker-turn'))
(p/'unmatched.json').write_text(json.dumps(manifest))
PY

test_case "responses deduplicate across files and include coordinator plus retained workers"
run_cmd "$TMPROOT" python3 "$COLLECTOR" --manifest "$TMPROOT/manifest.json" "$TMPROOT/a.jsonl" "$TMPROOT/b.jsonl"
assert_eq 0 "$R_STATUS" "valid cohort produces a report"
printf '%s\n' "$R_OUT" > "$TMPROOT/report.json"
cat > "$TMPROOT/check-report.py" <<'PY'
import json, sys
r=json.load(open(sys.argv[1]))
a=r['aggregate']
assert a['responses']==4
assert a['input_tokens']==1500 and a['cached_input_tokens']==1120
assert a['cached_token_share']==1120/1500
assert a['uncached_input_tokens']==380
assert a['output_tokens']==100 and a['reasoning_output_tokens']==8
assert a['total_tokens']==1600
assert a['total_usage_per_completed_ticket']==800
assert a['uncached_input_per_completed_ticket']==190
assert a['cache_write_input_tokens']==0
assert len(next(x for x in r['responses'] if x['response_id']=='r2')['sources'])==2
assert len(r['compaction_observations'])==1
assert len(r['runs'][0]['by_role_phase'])==3
phases=r['runs'][0]['by_request_phase']
assert any(x['dispatch_phase']=='subsequent' and x['request_phase']=='initial' and x['usage']['input_tokens']==200 for x in phases)
assert any(x['dispatch_phase']=='subsequent' and x['request_phase']=='subsequent' and x['usage']['input_tokens']==300 for x in phases)
assert r['runs'][0]['elapsed_seconds']==12.5
assert r['variants'][0]['usage']['cached_token_share']==1120/1500
assert r['variants'][0]['returned_bytes'] is None
print('deduplication, ratio of sums, subsets, provenance, phases, unknown read metrics verified')
PY
run_cmd "$TMPROOT" python3 "$TMPROOT/check-report.py" "$TMPROOT/report.json"
assert_eq 0 "$R_STATUS" "arithmetic and provenance survive mirrored/cumulative events"

test_case "missing cache counters remain unknown in complete and partial cohorts"
for source in missing partial; do
  run_cmd "$TMPROOT" python3 "$COLLECTOR" "$TMPROOT/$source.jsonl"
  assert_eq 0 "$R_STATUS" "$source usage is present"
  printf '%s\n' "$R_OUT" > "$TMPROOT/report.json"
  cat > "$TMPROOT/check-missing.py" <<'PY'
import json, sys
r=json.load(open(sys.argv[1]))['aggregate']
for key in ('cached_input_tokens','cache_write_input_tokens','cached_token_share','uncached_input_tokens'):
    assert r[key] is None, key
assert r['total_tokens'] in (110,220)
assert r['missing_counter_responses']['cached_input_tokens']==1
PY
  run_cmd "$TMPROOT" python3 "$TMPROOT/check-missing.py" "$TMPROOT/report.json"
  assert_eq 0 "$R_STATUS" "$source unknown counters are not silently zero-filled"
done

test_case "incomplete evidence and invalid counters fail instead of reporting savings"
for source in empty negative boolean fractional cached-overflow reasoning-overflow total-mismatch missing-id; do
  run_cmd "$TMPROOT" python3 "$COLLECTOR" "$TMPROOT/$source.jsonl"
  assert_eq 2 "$R_STATUS" "$source rejected"
  assert_contains "$R_ERR" '"status": "unavailable"' "$source cannot look measured"
done
run_cmd "$TMPROOT" python3 "$COLLECTOR" "$TMPROOT/a.jsonl" "$TMPROOT/conflict.jsonl"
assert_eq 2 "$R_STATUS" "conflicting duplicate response fails"
assert_contains "$R_ERR" 'conflicting duplicate response_id' "conflict names duplicate rather than picking one"
run_cmd "$TMPROOT" python3 "$COLLECTOR" --manifest "$TMPROOT/unmatched.json" "$TMPROOT/a.jsonl" "$TMPROOT/b.jsonl"
assert_eq 2 "$R_STATUS" "an expected worker without usage fails the cohort"
assert_contains "$R_ERR" 'usage unavailable for expected assignments' "missing worker is explicit"
test_case "read telemetry follows retained threads and canonical tool outputs"
cat > "$TMPROOT/check-metrics.py" <<'PY'
import json
import pathlib
import subprocess
import sys
root=pathlib.Path(sys.argv[1])/'telemetry'
run=root/'before-1'
(run/'reads').mkdir(parents=True)
assignments=[dict(thread_id='worker-thread',turn_id=turn,run_id='before-1',role='worker-1',phase=phase,worker_reused=reused)
             for turn,phase,reused in [('t1','initial',False),('t2','subsequent',True)]]
(root/'manifest.json').write_text(json.dumps({'runs':[{'run_id':'before-1'}],'assignments':assignments}))
def event(kind, payload): return dict(type=kind,payload=payload)
def save(name, rows): (run/name).write_text(''.join(json.dumps(r)+'\n' for r in rows))
first=[event('session_meta',{'id':'worker-thread'}),event('turn_context',{'turn_id':'t1'}),
       event('response_item',{'type':'function_call_output','call_id':'call1','output':'abc'}),
       event('event_msg',{'type':'item_completed','output':'abc'})]
save('worker-1-initial.session.jsonl',first)
save('worker-1-subsequent.session.jsonl',first+[
    event('turn_context',{'turn_id':'t2'}),
    event('response_item',{'type':'custom_tool_call_output','call_id':'call2','output':[{'type':'input_text','text':'é'}]}),
    dict(type='compacted',timestamp='2026-01-01',ordinal=12,payload={})])
for number,target in [(1,'/active/worktree-1/AGENTS.md'),(2,'/active/worktree-2/AGENTS.md'),
                      (3,'/active/project/.ai/sift/open/docs/ACME-0001--title.md')]:
    (run/f'reads/read{number}.args').write_text(target+'\t--all\t1\n')
    (run/f'reads/read{number}').write_text('page: 1/1; next: none\ncontent\n')
(run/'worker-1-initial.reads.json').write_text(json.dumps(['reads/read1.args','reads/read3.args']))
(run/'worker-1-subsequent.reads.json').write_text(json.dumps(['reads/read2.args']))
def collect():
    return json.loads(subprocess.check_output([sys.executable,sys.argv[2],str(root)]))['runs'][0]
r=collect()
assert r['returned_bytes']==5
assert r['ticket_bodies_emitted']==1
assert r['instruction_reads']==2
assert r['repeated_instruction_reads']==1
assert len(r['telemetry']['tool_outputs'])==2
assert len(r['telemetry']['tool_outputs'][0]['sources'])==2
assert len(r['telemetry']['compactions'])==1
assert r['telemetry']['read_attribution_complete'] is True
(run/'worker-1-subsequent.reads.json').unlink()
r=collect()
assert r['repeated_instruction_reads'] is None
assert r['instruction_reads']==2
assert r['telemetry']['read_attribution_complete'] is False
# A conflicting snapshot must fail, not arbitrarily win deduplication.
first[2]['payload']['output']='changed'
save('conflict.session.jsonl',first)
assert subprocess.run([sys.executable,sys.argv[2],str(root)],stdout=subprocess.PIPE,stderr=subprocess.PIPE).returncode==2
print('telemetry deduplication, UTF-8 bytes, retained-context reads, absent attribution and conflict verified')
PY
run_cmd "$TMPROOT" python3 "$TMPROOT/check-metrics.py" "$TMPROOT" "$DIR/../benchmarks/drain-cache-metrics.py"
assert_eq 0 "$R_STATUS" "telemetry measures emitted text and scoped repeated reads"
assert_contains "$R_OUT" 'telemetry deduplication' "fixture checks execute"
summary
