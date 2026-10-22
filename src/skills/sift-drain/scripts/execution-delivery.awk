# Join reconstructed graph, authoritative ticket state, current obligations and
# actual validate-declared results. No event's claimed pass substitutes for V.
BEGIN {FS=OFS="\t";OFMT="%.0f";CONVFMT="%.17g"}
$1=="metric" {metrics[$2]=$3; print; next}
$1=="wave" {waves[$2]=$6; wave_end[$2]=$5; print; next}
$1=="wave-metric" {if($3=="window_seconds") wave_seconds[$2]=$4; print; next}
$1=="gate" {gate_count[$3]++; if($4!="completed") gate_bad[$3]=1; print; next}
$1=="attempt" {attempt_nondelivery[$2]=($13 ~ /^(wontfix|superseded|cancelled)$/); print; next}
$1=="member" {
    tickets[$2]=1;wave_member[$2,$4]=1
    if(!($2 in classification)) classification[$2]=$5
    else if(classification[$2]!=$5) classification[$2]="unknown"
    print; next
}
$1=="ticket-event" {
    if($5=="landed") {
        landed[$2]=1
        land_attempt[$2,$3]=$4; land_attempt_time[$2,$3]=$7+0
    }
    else {
        ticket_outcome[$2,$3]=$6
        if($6=="done") returned[$2]=1
        if($6 ~ /^(wontfix|superseded|cancelled)$/) historical_nondelivery[$2]=1
    }
    print; next
}
$1=="check" {
    # Only gate-scoped integrated observations can satisfy wave obligations.
    # Results at the same clock tick may follow an invalidation. Failed versus
    # passed terminal results at that tick are uncertain, never ordered by IDs.
    if($5!="-") {
        k=$4 SUBSEP $6 SUBSEP $7
        if(!(k in latest) || $9+0>latest[k]) {latest[k]=$9+0; result[k]=""; refs[k]=""; conflict[k]=0}
        if($9+0==latest[k]) {
            if($8!="invalidated") {
                outcome=($8=="reused" ? "passed" : $8)
                if(result[k]!="" && result[k]!=outcome) conflict[k]=1
                result[k]=outcome
                # Multiple independently valid references may appear at one tick;
                # each must validate, avoiding arbitrary scan-order selection.
                refs[k]=refs[k] $10 "\034"
            }
        }
    }
    print; next
}
$1=="T" {state_count[$2]++; state[$2]=$3; next}
$1=="O" {obligations[$2]=$3; scopes[$2]=$4; declaration[$2]=$5; next}
$1=="V" {valid[$2,$3,$4,$5]=$6; print "evidence",$2,$3,$4,$5,$6,$7; next}
$1=="C" {declarations_ok=$2; next}
$1=="F" {
    deferred[$2,$3,$4,$6]=$7
    if($7=="true") print "deferral",$2,$3,$4,$5,$6,$8,$9,$10,$11
    else print "diagnostic","unauthorized-deferral",$6
    next
}
{print}
function metric(k,x) {print "metric",k,x}
function hourly_rate(tickets,seconds) {
    return seconds!="-" && seconds+0>0 ? sprintf("%.6f",3600*tickets/seconds) : "-"
}
function obligation_ok(w,id,   key,n,paths,j) {
    key=w SUBSEP id SUBSEP obligations[id]
    if(declaration[id]!="complete" || !(key in latest) || conflict[key] || result[key]!="passed") return 0
    n=split(refs[key],paths,"\034")
    if(n<2) return 0
    for(j=1;j<n;j++) if(valid[id,obligations[id],scopes[id],paths[j]]!="true") return 0
    return 1
}
function obligation_deferred(w,id,   key,n,paths,j) {
    key=w SUBSEP id SUBSEP obligations[id]
    if(obligations[id]!="compatibility" || declaration[id]!="complete" || conflict[key] || result[key]!="deferred") return 0
    n=split(refs[key],paths,"\034")
    if(n<2) return 0
    for(j=1;j<n;j++) if(deferred[w,id,obligations[id],paths[j]]!="true") return 0
    return 1
}
END {
    # The shell asks this same join for its bounded validation worklist first.
    # It filters R rows; the normal report never emits this internal row type.
    if(ENVIRON["SIFT_REPORT_REQUESTS"]=="1") {
        for(w in waves) for(id in obligations) {
            k=w SUBSEP id SUBSEP obligations[id]
            if(!conflict[k] && result[k]=="passed" && declaration[id]=="complete") {
                n=split(refs[k],paths,"\034")
                for(j=1;j<n;j++) print "R",id,obligations[id],scopes[id],paths[j]
            }
        }
        exit
    }
    for(w in waves) {
        dev=0; total=0; dev_ok=declarations_ok; full_ok=declarations_ok
        for(id in obligations) {
            total++;ok=obligation_ok(w,id)
            if(conflict[w,id,obligations[id]]) print "diagnostic","conflicting-check-results",w "/" id
            if(obligations[id]=="development") {dev++; if(!ok) dev_ok=0}
            if(!ok) full_ok=0
            defer=(!ok && declarations_ok && obligation_deferred(w,id))
            if(defer) authorized_deferrals++
            print "obligation",w,id,obligations[id],scopes[id],(ok ? "passed" : (defer ? "authorized-deferral" : "outstanding"))
        }
        development[w]=(dev>0 && dev_ok && metrics["integrity_errors"]==0)
        full[w]=(total>0 && full_ok && development[w] && waves[w] ~ /^(done|passed)$/ && gate_count[w]>0 && !gate_bad[w])
        if(full[w]) verified_waves++
    }
    # Historical non-delivery remains observable, but eligibility belongs to the
    # implementation/landing pair. A later linked retry can deliver the ticket.
    # A cancelled attempt's done return alone cannot establish implementation.
    for(pair in land_attempt) {
        split(pair,parts,SUBSEP);t=parts[1];a=parts[2];w=land_attempt[pair]
        if(ticket_outcome[pair]=="done" && !attempt_nondelivery[a]) {
            eligible_land[t,w]=1
            if(land_attempt_time[pair]>land_time[t,w]) land_time[t,w]=land_attempt_time[pair]
        }
    }
    for(t in tickets) {
        s=state_count[t]==1 ? state[t] : "unknown"
        if(s=="unknown") {unknown_state++;print "diagnostic","ticket-state-unavailable",t}
        if(s=="done") done++
        if(s ~ /^(done|wontfix|superseded)$/) resolved++
        if(s ~ /^(wontfix|superseded)$/ || historical_nondelivery[t]) non_delivery++
        if(returned[t]) returned_count++
        if(landed[t]) landed_count++
        c=classification[t]
        if(c=="") c="unknown"
        dv=0;fv=0
        for(w in waves) if(wave_member[t,w]) {
            wd=(s=="done" && eligible_land[t,w] && development[w])
            wf=(wd && full[w] && wave_end[w]+0>=land_time[t,w])
            if(wd) dv=1
            if(wf) {fv=1;if(c=="product") wave_product[w]++}
            print "wave-ticket",w,t,c,(wd ? "development-verified" : "-"),(wf ? "fully-verified" : "-")
        }
        if(dv) dev_count[c]++
        if(fv) full_count[c]++
        print "ticket",t,s,c,(returned[t] ? "returned-done" : "-"),(landed[t] ? "landed" : "-"),(dv ? "development-verified" : "-"),(fv ? "fully-verified" : "-"),(historical_nondelivery[t] ? "non-delivery-outcome" : "-")
    }
    for(w in waves) {
        print "wave-metric",w,"throughput_denominator_seconds",wave_seconds[w]
        print "wave-metric",w,"throughput_numerator_tickets",wave_product[w]+0
        print "wave-metric",w,"fully_verified_product_per_hour",hourly_rate(wave_product[w],wave_seconds[w])
    }
    metric("authoritative_done",done+0);metric("backlog_resolved",resolved+0)
    metric("unknown_ticket_states",unknown_state+0)
    metric("returned_done",returned_count+0);metric("landed",landed_count+0);metric("non_delivery",non_delivery+0)
    metric("development_verified_product",dev_count["product"]+0);metric("fully_verified_product",full_count["product"]+0)
    metric("development_verified_infrastructure",dev_count["infrastructure"]+0);metric("fully_verified_infrastructure",full_count["infrastructure"]+0)
    metric("development_verified_unknown",dev_count["unknown"]+0);metric("fully_verified_unknown",full_count["unknown"]+0)
    metric("fully_verified_waves",verified_waves+0)
    metric("authorized_compatibility_deferrals",authorized_deferrals+0)
    metric("throughput_denominator_seconds",metrics["window_seconds"])
    metric("throughput_numerator_tickets",full_count["product"]+0)
    metric("fully_verified_product_per_hour",hourly_rate(full_count["product"],metrics["window_seconds"]))
}
