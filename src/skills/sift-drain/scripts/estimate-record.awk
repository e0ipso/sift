# Validate the immutable publication marker before selecting or rendering it.
function fail(s) { print "error: estimate record: " s | "cat >&2"; close("cat >&2"); bad=1; exit 2 }
function epoch(s) { return length(s)<=15 && s ~ /^(0|[1-9][0-9]*)$/ }
BEGIN { FS="\t" }
NR==1 { if($0!="# Execution estimate v1") fail("unsupported header"); next }
NR==2 { if($0!="") fail("missing blank line"); next }
{
    line=$0; gsub("\t","",line)
    if(line ~ /[^[:print:]]/) fail("non-ASCII row")
    if($1=="estimate") {
        if(NF!=3 || $3=="" || ($2 in value)) fail("invalid/duplicate field")
        value[$2]=$3
    } else if($1=="sample") {if(NF!=10) fail("invalid sample")}
    else if($1=="cohort") {if(NF!=9) fail("invalid cohort")}
    else if($1=="entity") {if(NF!=6) fail("invalid entity")}
    else if($1=="diagnostic") {if(NF!=3) fail("invalid diagnostic")}
    else if($1=="external") {if(NF!=4) fail("invalid external blocker")}
    else fail("unknown row")
}
END {
    if(bad) exit 2
    n=split("id run_id origin_epoch previous revision_reason graph_fingerprint input_fingerprint scope capacity retry_policy retry_allowance_low retry_allowance_high retry_reason scenario assumptions status lower_epoch upper_epoch full_completion_upper_epoch external_blockers",required," ")
    for(i=1;i<=n;i++) {if(!(required[i] in value)) fail("missing " required[i]); known[required[i]]=1}
    for(k in value) if(!(k in known)) fail("unknown field " k)
    if(value["id"]!=ENVIRON["ETA_ID"] || value["run_id"]!=ENVIRON["ETA_RUN"]) fail("identity/path mismatch")
    if(value["previous"]!="-" && (value["previous"] !~ /^estimate\.[[:alnum:]]+$/ || value["previous"]==value["id"])) fail("invalid previous identity")
    if(!epoch(value["origin_epoch"])) fail("invalid origin")
    n=split("lower_epoch upper_epoch full_completion_upper_epoch",bounds," ")
    for(i=1;i<=n;i++) if(value[bounds[i]]!="-" && (!epoch(value[bounds[i]]) || value[bounds[i]]+0<value["origin_epoch"]+0)) fail("invalid bound")
    if(value["status"] !~ /^(scenario|unavailable|conditional-external-blockers)$/) fail("invalid status")
    if(value["lower_epoch"]!="-" && value["upper_epoch"]!="-" && value["lower_epoch"]+0>value["upper_epoch"]+0) fail("lower bound exceeds upper bound")
    if(!epoch(value["external_blockers"]) || !epoch(value["retry_allowance_low"]) || !epoch(value["retry_allowance_high"]) || value["retry_allowance_low"]+0>value["retry_allowance_high"]+0) fail("invalid count/allowance")
    if(value["status"]=="unavailable") {
        if(value["lower_epoch"]!="-" || value["upper_epoch"]!="-" || value["full_completion_upper_epoch"]!="-") fail("unavailable estimate has numeric bounds")
    } else {
        if(value["lower_epoch"]=="-" || value["upper_epoch"]=="-") fail("scenario lacks bounds")
        if(value["external_blockers"]+0>0) {
            if(value["status"]!="conditional-external-blockers" || value["full_completion_upper_epoch"]!="-") fail("external blocker has finite full completion")
        } else if(value["status"]!="scenario" || value["full_completion_upper_epoch"]!=value["upper_epoch"]) fail("inconsistent full completion bound")
    }
}
