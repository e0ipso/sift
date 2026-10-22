# Identity graph and interval arithmetic. Input is validated decoded event fields.
# No filesystem access or shell evaluation occurs in this program.
BEGIN { FS=OFS="\t"; OFMT="%.0f"; CONVFMT="%.17g"; now=ENVIRON["SIFT_REPORT_NOW"]+0; run=ENVIRON["SIFT_REPORT_RUN"]; n=0 }
$1=="D" { diagnostic($2,$3); next }
$1=="E" { e=++n; eid[e]=$2; next }
{ v[e,$1]=$2 }
function given(s) { return s=="" ? "-" : s }
function metric(k,x) { print "metric",k,x }
function diagnostic(code,id) { print "diagnostic",code,id; issues++; if(code=="incomplete-publication") pending++ }
function reject(e,code) { if (!bad[e]) diagnostic(code,eid[e]); bad[e]=1 }
function subject(e,   k) {
    k=v[e,"kind"]
    if(k ~ /^run-/) return run
    if(k ~ /^wave-/) return v[e,"wave_id"]
    if(k=="sitting") return v[e,"sitting_id"]
    if(k=="gate") return v[e,"gate_id"]
    if(k ~ /^(span|wait)-/) return v[e,"span_id"]
    return v[e,"attempt_id"]
}
function signature(e,   j,k,s) {
    s=""
    for(j=1;j<=nk;j++) { k=keys[j]; s=s length(v[e,k]) ":" v[e,k] }
    return s
}
function member(list,t) { return index("," list ",","," t ",")>0 }
function subset(child,parent,   a,m,j,p,last) {
    if(child=="-") return parent=="-"
    m=split(child,a,","); last=0
    for(j=1;j<=m;j++) {
        p=index("," parent ",","," a[j] ",")
        if(!p || p<=last) return 0
        last=p
    }
    return 1
}
function parent(e,p,   t) {
    if(!p) { reject(e,"unresolved-reference"); return 0 }
    if(bad[p]) { reject(e,"invalid-parent"); return 0 }
    t=v[e,"timestamp"]+0
    if(t<v[p,"timestamp"]+0) { reject(e,"before-parent"); return 0 }
    return 1
}
# Sort a subject's transitions by clock, not publication. At one timestamp the
# current state determines the only admissible interrupt/resume order.
function lifecycle(start,terminal,subject_id,prefix,   list,m,e,i,j,x,state,k,t) {
    m=0
    for(e=1;e<=n;e++) if(!duplicate[e] && !bad[e] && subject(e)==subject_id &&
        (v[e,"kind"]==prefix "-interrupt" || v[e,"kind"]==prefix "-resume")) list[++m]=e
    for(i=2;i<=m;i++) {
        x=list[i]; j=i-1
        while(j>0 && v[list[j],"timestamp"]+0>v[x,"timestamp"]+0) {list[j+1]=list[j];j--}
        list[j+1]=x
    }
    state="active"
    for(i=1;i<=m;i++) {
        e=list[i]; t=v[e,"timestamp"]+0
        k=prefix (state=="active" ? "-interrupt" : "-resume")
        if(v[e,"kind"]!=k) {
            for(j=i+1;j<=m && v[list[j],"timestamp"]+0==t;j++) if(v[list[j],"kind"]==k) {
                x=list[i];list[i]=list[j];list[j]=x;e=list[i];break
            }
        }
        if(terminal && t>v[terminal,"timestamp"]+0) { reject(e,"resume-after-terminal"); continue }
        if(!parent(e,start)) continue
        if(v[e,"kind"]!=k) { reject(e,"invalid-lifecycle-transition"); continue }
        state=(state=="active" ? "interrupted" : "active")
        transition_state[subject_id,t]=state
        if(state=="active") resumes++
    }
    return state
}
function stopped_at(a,t,   e,last,state,time) {
    last=-1;state="active"
    for(e=1;e<=n;e++) if(!bad[e] && !duplicate[e] && v[e,"attempt_id"]==a && v[e,"kind"] ~ /^attempt-(interrupt|resume)$/) {
        time=v[e,"timestamp"]+0
        if(time<=t && time>=last) {last=time;state=transition_state[a,time]}
    }
    return state=="interrupted"
}
function add_interval(group,s,t,   i) {
    i=++count[group]; left[group,i]=s; right[group,i]=t
}
# Sorting endpoints within each group keeps concurrent effort distinct from the
# elapsed union. Every span enters its attempt once, never its parent envelope.
function union(group,   i,j,s,t,end,total) {
    for(i=2;i<=count[group];i++) {
        s=left[group,i]; t=right[group,i]; j=i-1
        while(j>0 && left[group,j]>s) {
            left[group,j+1]=left[group,j]; right[group,j+1]=right[group,j]; j--
        }
        left[group,j+1]=s; right[group,j+1]=t
    }
    total=0; end=-1
    for(i=1;i<=count[group];i++) {
        s=left[group,i]; t=right[group,i]
        if(s>end) total+=t-s
        else if(t>end) total+=t-end
        if(t>end) end=t
    }
    return total
}
END {
    nk=split("kind run_id actor actor_id timestamp wave_id wave sitting_id gate_id attempt_id members retry_of span_id activity outcome duration reason reason_detail wait_class work_class stage relation ticket_id origin_attempt_id origin_gate_id root_cause check_id exit_status external_id evidence_ref",keys," ")
    # Declarations/terminals use subject identity. Repeated transitions include
    # their timestamp: recurring interruptions are not conflicting terminals.
    for(e=1;e<=n;e++) {
        k=v[e,"kind"]; id=subject(e); key=k SUBSEP id
        if(k ~ /-(interrupt|resume)$/) key=key SUBSEP v[e,"timestamp"]
        if(k=="ticket-outcome" || k=="landed") key=key SUBSEP v[e,"ticket_id"]
        if(k=="check") key=key SUBSEP v[e,"check_id"] SUBSEP v[e,"stage"] SUBSEP v[e,"timestamp"] SUBSEP v[e,"outcome"]
        if(k=="link") key=k SUBSEP v[e,"origin_attempt_id"] SUBSEP v[e,"origin_gate_id"] SUBSEP v[e,"ticket_id"] SUBSEP v[e,"relation"]
        sig=signature(e)
        if(key in semantic) {
            old=semantic[key]
            if(sig==signatures[key]) { duplicate[e]=1; duplicates++; continue }
            reject(old,"conflicting-event"); reject(e,"conflicting-event")
        } else { semantic[key]=e; signatures[key]=sig }
        if(k=="run-start") rs=e
        if(k=="run-end") re=e
        if(k=="wave-start") waves[id]=e
        if(k=="wave-end") wave_end[id]=e
        if(k=="sitting") sittings[id]=e
        if(k=="gate") gates[id]=e
        if(k=="attempt-start") attempts[id]=e
        if(k=="attempt-end") ends[id]=e
        if(k=="span-start" || k=="wait-start") {
            if(id in spans) { reject(spans[id],"conflicting-span-kind"); reject(e,"conflicting-span-kind") }
            spans[id]=e
        }
        if(k=="span-end" || k=="wait-end") {
            if(id in span_end) {reject(span_end[id],"conflicting-span-terminal");reject(e,"conflicting-span-terminal")}
            span_end[id]=e
        }
    }
    if(!rs) diagnostic("unresolved-run",run)
    window_start=(rs && !bad[rs]) ? v[rs,"timestamp"]+0 : -1
    window_end=(re && !bad[re]) ? v[re,"timestamp"]+0 : now
    if(window_start>window_end || window_end>now) { diagnostic("invalid-window",run); window_start=-1 }
    for(e=1;e<=n;e++) {
        if(duplicate[e] || bad[e]) continue
        k=v[e,"kind"]; id=subject(e)
        if(v[e,"timestamp"]+0>now) { reject(e,"after-observation"); continue }
        if(k!="run-start" && !parent(e,rs)) continue
        if(re && !bad[re] && v[e,"timestamp"]+0>v[re,"timestamp"]+0) reject(e,"after-run-terminal")
        if(k=="sitting" || k=="gate" || k=="attempt-start" || k=="wave-end") parent(e,waves[v[e,"wave_id"]])
        if(k=="attempt-start") {
            p=(v[e,"sitting_id"]!="") ? sittings[v[e,"sitting_id"]] : gates[v[e,"gate_id"]]
            if(parent(e,p)) {
                if(v[p,"wave_id"]!=v[e,"wave_id"]) reject(e,"parent-wave-mismatch")
                if(v[e,"sitting_id"]!="" && !subset(v[e,"members"],v[p,"members"])) reject(e,"invalid-ordered-membership")
                if(v[e,"gate_id"]!="" && v[e,"members"]!="-") reject(e,"gate-has-members")
            }
        } else if(v[e,"attempt_id"]!="") {
            p=attempts[v[e,"attempt_id"]]
            if(parent(e,p)) {
                if(v[e,"wave_id"]!="" && v[e,"wave_id"]!=v[p,"wave_id"]) reject(e,"parent-wave-mismatch")
                if(v[e,"ticket_id"]!="" && !member(v[p,"members"],v[e,"ticket_id"])) reject(e,"ticket-outside-attempt")
                if(v[e,"sitting_id"]!="" && v[e,"sitting_id"]!=v[p,"sitting_id"]) reject(e,"parent-sitting-mismatch")
                if(v[e,"gate_id"]!="" && v[e,"gate_id"]!=v[p,"gate_id"]) reject(e,"parent-gate-mismatch")
                t=ends[v[e,"attempt_id"]]
                if(t && k ~ /^(span|wait|check|ticket-outcome)/ && v[e,"timestamp"]+0>v[t,"timestamp"]+0) reject(e,"after-attempt-terminal")
            }
        }
        w=v[e,"wave_id"]
        if(w=="" && v[e,"attempt_id"]!="") w=v[attempts[v[e,"attempt_id"]],"wave_id"]
        if(w!="" && wave_end[w] && v[e,"timestamp"]+0>v[wave_end[w],"timestamp"]+0) reject(e,"after-wave-terminal")
        if(k=="span-end" || k=="wait-end") parent(e,spans[v[e,"span_id"]])
        if(k=="run-end" || k=="wave-end" || k=="attempt-end") {
            p=(k=="run-end" ? rs : (k=="wave-end" ? waves[v[e,"wave_id"]] : attempts[v[e,"attempt_id"]]))
            if(p && v[e,"duration"]!="" && v[e,"timestamp"]-v[p,"timestamp"]!=v[e,"duration"]+0) reject(e,"invalid-interval")
        }
        if(k=="link") {
            if(v[e,"origin_attempt_id"]!="") parent(e,attempts[v[e,"origin_attempt_id"]])
            if(v[e,"origin_gate_id"]!="") parent(e,gates[v[e,"origin_gate_id"]])
            if(v[e,"origin_attempt_id"]!="" && v[e,"origin_gate_id"]!="" && v[attempts[v[e,"origin_attempt_id"]],"gate_id"]!=v[e,"origin_gate_id"]) reject(e,"link-origin-mismatch")
        }
    }
    run_state=lifecycle(rs,re,run,"run")
    for(a in attempts) attempt_state[a]=lifecycle(attempts[a],ends[a],a,"attempt")
    for(a in attempts) {
        e=attempts[a]; t=ends[a]
        r=v[e,"retry_of"]
        if(r!="") {
            p=attempts[r]
            if(parent(e,p)) {
                if(v[e,"wave_id"]!=v[p,"wave_id"] || v[e,"sitting_id"]!=v[p,"sitting_id"] || v[e,"gate_id"]!=v[p,"gate_id"] || !subset(v[e,"members"],v[p,"members"])) reject(e,"invalid-retry-parent")
                if(!ends[r] && !stopped_at(r,v[e,"timestamp"]+0)) reject(e,"retry-without-stop")
                if(ends[r] && v[ends[r],"timestamp"]+0>v[e,"timestamp"]+0) reject(e,"retry-before-terminal")
            }
            # Walk ancestry with a bound, so cycles and older preserved members
            # cannot be hidden by a narrowed intermediate retry.
            hops=0
            while(r!="" && (r in attempts) && hops++<=n) {
                if(r==a) {reject(e,"retry-cycle");break}
                for(j=1;j<=n;j++) if(!duplicate[j] && v[j,"attempt_id"]==r &&
                    (v[j,"kind"]=="landed" || (v[j,"kind"]=="ticket-outcome" && v[j,"outcome"]=="done")) &&
                    v[j,"timestamp"]+0<=v[e,"timestamp"]+0 && member(v[e,"members"],v[j,"ticket_id"])) reject(e,"retry-preserved-member")
                r=v[attempts[r],"retry_of"]
            }
            if(hops>n) reject(e,"retry-cycle")
        }
    }
    # Propagate invalid declarations after all references have been resolved.
    changed=1
    while(changed) {
      changed=0
      for(e=1;e<=n;e++) if(!duplicate[e] && !bad[e]) {
        k=v[e,"kind"]
        if(bad[rs] || (v[e,"wave_id"]!="" && bad[waves[v[e,"wave_id"]]]) ||
           (v[e,"sitting_id"]!="" && bad[sittings[v[e,"sitting_id"]]]) ||
           (v[e,"gate_id"]!="" && bad[gates[v[e,"gate_id"]]]) ||
           (v[e,"attempt_id"]!="" && bad[attempts[v[e,"attempt_id"]]]) ||
           (v[e,"retry_of"]!="" && bad[attempts[v[e,"retry_of"]]])) {reject(e,"invalid-parent");changed=1}
      }
    }
    window_start=(rs && !bad[rs]) ? v[rs,"timestamp"]+0 : -1
    window_end=(re && !bad[re]) ? v[re,"timestamp"]+0 : now
    if(window_start>window_end || window_end>now) window_start=-1
    for(a in attempts) {
        e=attempts[a]; t=ends[a]; w=v[e,"wave_id"]
        if(bad[waves[w]]) reject(e,"invalid-parent")
        if(t && !bad[t] && v[t,"timestamp"]+0<v[e,"timestamp"]+0) reject(t,"invalid-interval")
        state=bad[e] ? "invalid" : ((!t || bad[t]) ? "incomplete" : "completed")
        duration=state=="completed" ? v[t,"timestamp"]-v[e,"timestamp"] : "-"
        class=v[e,"work_class"]
        if(class=="") class=v[(v[e,"sitting_id"]!="" ? sittings[v[e,"sitting_id"]] : gates[v[e,"gate_id"]]),"work_class"]
        if(class=="") class="unknown"
        attempt_class[a]=class
        ast[a]=state
        print "attempt",a,w,(v[e,"gate_id"]!="" ? "gate" : "sitting"),given(v[e,"sitting_id"] v[e,"gate_id"]),v[e,"members"],given(v[e,"retry_of"]),class,v[e,"timestamp"],(t && !bad[t] ? v[t,"timestamp"] : "-"),duration,state,(t && !bad[t] ? v[t,"outcome"] : "-"),v[e,"actor"],given(v[e,"actor_id"]),given(v[e,"external_id"]),attempt_state[a]
        total_attempts++
        if(state=="completed") {
            samples[++completed]=duration
            if(v[e,"gate_id"]!="") add_interval("gate-envelope",v[e,"timestamp"]+0,v[t,"timestamp"]+0)
        } else if(state=="invalid") invalid_attempts++
        else { incomplete++; lower_bound+=window_end-v[e,"timestamp"] }
        if(v[e,"retry_of"]!="") retries++
    }
    for(id in spans) {
        e=spans[id]; t=span_end[id]; a=v[e,"attempt_id"]; p=attempts[a]
        label=(v[e,"kind"]=="wait-start" ? v[e,"reason"] : v[e,"activity"])
        if(bad[p]) reject(e,"invalid-parent")
        if(t && (v[t,"attempt_id"]!=a || (v[e,"kind"]=="wait-start")!=(v[t,"kind"]=="wait-end"))) reject(t,"span-parent-mismatch")
        if(t && !bad[t] && (v[t,"timestamp"]+0<v[e,"timestamp"]+0 || v[t,"timestamp"]-v[e,"timestamp"]!=v[t,"duration"]+0)) reject(t,"invalid-interval")
        if(bad[e] || (t && bad[t])) { invalid_spans++; continue }
        if(!t) { missing_spans++; print "span",id,a,"incomplete",v[e,"timestamp"],"-","-",v[e,"kind"],label,given(v[e,"wait_class"]); continue }
        s=v[e,"timestamp"]+0; end=v[t,"timestamp"]+0
        print "span",id,a,"completed",s,end,end-s,v[e,"kind"],label,given(v[e,"wait_class"])
        add_interval("occupied",s,end)
        if(v[p,"gate_id"]!="") add_interval("gate",s,end)
        if(v[e,"kind"]=="wait-start") {
            label=v[e,"reason"] SUBSEP v[e,"wait_class"]; waits[label]=1
            add_interval("wait" SUBSEP label,s,end)
            add_interval("waiting",s,end)
            add_interval("waiting" SUBSEP v[e,"wait_class"],s,end)
        } else {
            add_interval("effort" SUBSEP a,s,end)
            activities[v[e,"activity"]]=1;add_interval("activity" SUBSEP v[e,"activity"],s,end)
        }
    }
    for(a in attempts) effort+=union("effort" SUBSEP a)
    for(label in waits) { split(label,parts,SUBSEP); print "wait",parts[1],parts[2],union("wait" SUBSEP label) }
    for(label in activities) print "activity",label,union("activity" SUBSEP label)
    for(i=2;i<=completed;i++) { x=samples[i]; j=i-1; while(j>0 && samples[j]>x) {samples[j+1]=samples[j];j--} samples[j+1]=x }
    occupied=union("occupied")
    metric("report_version",1); metric("run_id",run); metric("observation_epoch",sprintf("%.0f",now))
    metric("published_events",n)
    metric("run_state",rs && !bad[rs] ? (re && !bad[re] ? "completed" : run_state) : "invalid")
    metric("window_basis",re && !bad[re] ? "run-start/run-end" : "run-start/observation")
    metric("window_start",window_start<0 ? "-" : sprintf("%.0f",window_start)); metric("window_end",sprintf("%.0f",window_end))
    metric("window_seconds",window_start<0 ? "-" : window_end-window_start)
    metric("attempts",total_attempts+0); metric("completed_attempts",completed+0); metric("incomplete_attempts",incomplete+0)
    metric("attempt_duration_p50_seconds",completed ? samples[int((completed+1)/2)] : "-")
    metric("attempt_duration_min_seconds",completed ? samples[1] : "-")
    metric("attempt_duration_max_seconds",completed ? samples[completed] : "-")
    metric("retry_attempts",retries+0); metric("retry_denominator_attempts",total_attempts+0)
    metric("retry_rate",total_attempts ? sprintf("%.6f",retries/total_attempts) : "-")
    metric("effort_seconds",effort+0); metric("occupied_seconds",occupied)
    metric("waiting_seconds",union("waiting")); metric("external_wait_seconds",union("waiting" SUBSEP "external")); metric("actionable_wait_seconds",union("waiting" SUBSEP "actionable"))
    metric("gate_occupied_seconds",union("gate")); metric("gate_envelope_seconds",union("gate-envelope"))
    metric("unattributed_seconds",window_start<0 ? "-" : window_end-window_start-occupied)
    metric("incomplete_attempt_elapsed_lower_bound_seconds",lower_bound+0)
    metric("missing_span_terminals",missing_spans+0); metric("invalid_spans",invalid_spans+0)
    metric("semantic_duplicates",duplicates+0); metric("diagnostics",issues+0)
    metric("resume_transitions",resumes+0); metric("invalid_attempts",invalid_attempts+0)
    metric("incomplete_publications",pending+0)
    metric("integrity_errors",issues+0)
    for(s in sittings) {
        e=sittings[s]
        print "sitting",s,v[e,"wave_id"],v[e,"members"],(v[e,"work_class"]=="" ? "unknown" : v[e,"work_class"]),v[e,"timestamp"],(bad[e] ? "invalid" : "declared")
    }
    for(w in waves) {
        e=waves[w];t=wave_end[w]
        print "wave",w,v[e,"wave"],v[e,"timestamp"],(t && !bad[t] ? v[t,"timestamp"] : "-"),(t && !bad[t] && !bad[e] ? v[t,"outcome"] : "incomplete")
        # An absent terminal has an observed window, not a completed duration.
        # A present but invalid terminal cannot silently become an open window.
        ws=v[e,"timestamp"]+0;we=(t ? v[t,"timestamp"]+0 : now)
        window_ok=(!bad[e] && (!t || !bad[t]) && ws<=we && we<=now)
        print "wave-metric",w,"window_basis",(window_ok ? (t ? "wave-start/wave-end" : "wave-start/observation") : "unavailable")
        print "wave-metric",w,"window_start",(window_ok ? sprintf("%.0f",ws) : "-")
        print "wave-metric",w,"window_end",(window_ok ? sprintf("%.0f",we) : "-")
        print "wave-metric",w,"window_seconds",(window_ok ? we-ws : "-")
    }
    for(g in gates) {
        good=!bad[gates[g]]; heads=0
        for(a in attempts) if(v[attempts[a],"gate_id"]==g) {
            child=0
            for(b in attempts) if(v[attempts[b],"retry_of"]==a && !bad[attempts[b]]) child=1
            if(!child) {
                heads++;t=ends[a]
                if(ast[a]!="completed" || v[t,"outcome"]!~/^(done|passed)$/) good=0
            }
        }
        e=gates[g]
        print "gate",g,v[e,"wave_id"],(good && heads ? "completed" : "incomplete"),(v[e,"work_class"]=="" ? "unknown" : v[e,"work_class"]),v[e,"timestamp"]
    }
    for(a in attempts) if(!bad[attempts[a]]) {
        e=attempts[a];m=split(v[e,"members"],member_ids,",")
        for(i=1;i<=m;i++) if(member_ids[i]!="-") {
            class=attempt_class[a]
            for(j=1;j<=n;j++) if(!bad[j] && !duplicate[j] && v[j,"kind"]=="ticket-outcome" && v[j,"attempt_id"]==a && v[j,"ticket_id"]==member_ids[i] && v[j,"work_class"]!="") class=v[j,"work_class"]
            print "member",member_ids[i],a,v[e,"wave_id"],class
        }
    }
    for(e=1;e<=n;e++) if(!bad[e] && !duplicate[e]) {
        k=v[e,"kind"];a=v[e,"attempt_id"];p=attempts[a];w=v[p,"wave_id"]
        if(k ~ /^(run|attempt)-(interrupt|resume)$/) print "transition",k,subject(e),v[e,"timestamp"],given(v[e,"reason"])
        if(k=="ticket-outcome" || k=="landed")
            print "ticket-event",v[e,"ticket_id"],a,w,k,given(v[e,"outcome"]),v[e,"timestamp"],given(v[e,"evidence_ref"])
        if(k=="check")
            print "check",eid[e],a,w,given(v[p,"gate_id"]),v[e,"check_id"],v[e,"stage"],v[e,"outcome"],v[e,"timestamp"],v[e,"evidence_ref"],given(v[e,"reason"])
    }
    for(e=1;e<=n;e++) if(!duplicate[e] && !bad[e] && v[e,"kind"]=="link")
        print "link",v[e,"relation"],v[e,"ticket_id"],given(v[e,"origin_attempt_id"]),given(v[e,"origin_gate_id"]),given(v[e,"root_cause"])
}
