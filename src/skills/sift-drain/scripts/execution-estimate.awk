# Read declarations and the public report; never reconstruct event identities.
function fail(s) { print "error: estimate declaration: " s | "cat >&2"; close("cat >&2"); bad=1; exit 2 }
function token(s) { return length(s)<=128 && s ~ /^[[:alnum:]][[:alnum:]_.-]*$/ }
function integer(s) { return length(s)<=15 && s ~ /^(0|[1-9][0-9]*)$/ }
function stage(s) { return s ~ /^(development|compatibility|mixed)$/ }
function max(a,b) { return a>b ? a : b }
function ceil(a) { return int(a)+(a>int(a)) }
function unavailable(s,id) { print "diagnostic",s,id; missing=1 }
function count_members(s,   a,n,i,p) {
    if(s=="-") return 0
    n=split(s,a,","); p=ENVIRON["ETA_PREFIX"] "-"
    for(i=1;i<=n;i++) {
        if(substr(a[i],1,length(p))!=p || substr(a[i],length(p)+1) !~ /^[0-9][0-9][0-9][0-9][0-9]*$/) fail("invalid ticket member")
        if(member_owner[a[i]]++) fail("member charged more than once: " a[i])
    }
    return n
}
BEGIN { FS=OFS="\t"; now=ENVIRON["ETA_NOW"]+0; nodes=0; edges=0; samples=0; waves=0 }
FILENAME==ARGV[1] {
    line=$0; gsub("\t","",line)
    if(NR>10000 || length($0)>8192 || line ~ /[^[:print:]]/) fail("oversized or non-ASCII declaration")
    for(i=1;i<=NF;i++) if($i=="") fail("empty field at line " FNR)
    if($1=="meta") {
        if(NF!=3 || $2 !~ /^(version|scope|graph|ownership|obligations|capacity|capacity_epoch|admission_ref|environment|retry_policy|retry_low|retry_high|retry_reason)$/ || ($2 in meta)) fail("unknown/duplicate metadata: " $2)
        meta[$2]=$3
    } else if($1=="scope-wave") {
        if(NF!=2 || !token($2) || scope[$2]++) fail("invalid/duplicate scope-wave")
        waves++
    } else if($1=="node") {
        if(NF!=9 || !token($2) || ($2 in kind) || ++nodes>128) fail("invalid/duplicate node")
        if($3 !~ /^(sitting|gate)$/ || $4 !~ /^(product|infrastructure|unknown)$/ || !integer($5) || !stage($6) || !token($7) || $9 !~ /^(work|known-repair)$/) fail("invalid node classification")
        if($5!=count_members($8) || ($3=="gate" && $5!=0) || ($3=="sitting" && $5==0)) fail("group size disagrees with members")
        kind[$2]=$3; cls[$2]=$4; size[$2]=$5; stg[$2]=$6; env[$2]=$7; members[$2]=$8; purpose[$2]=$9
        ids[nodes]=$2
    } else if($1=="edge") {
        if(NF!=4 || !token($2) || !token($3) || $4 !~ /^(dependency|ownership)$/ || edge[$2,$3] || ++edges>4096) fail("invalid/duplicate edge")
        edge[$2,$3]=$4
    } else if($1=="obligation") {
        if(NF!=6 || !token($2) || !token($3) || !token($4) || $5 !~ /^(development|compatibility)$/ || !token($6)) fail("invalid obligation")
        k=$3 SUBSEP $4 SUBSEP $5 SUBSEP $6
        if(k in obligation) fail("shared obligation charged more than once")
        obligation[k]=$2; obligation_stage[k]=$5; obligation_wave[k]=$3
    } else if($1=="sample") {
        if(NF!=4 || !token($2) || !stage($3) || !token($4) || ($2 in sample_stage) || ++samples>2048) fail("invalid/duplicate sample assumption")
        sample_stage[$2]=$3; sample_env[$2]=$4
    } else if($1=="external") {
        if(NF!=4 || !token($2) || !token($3) || external[$2,$3]++) fail("invalid/duplicate external blocker")
        blocker[++blockers]=$0; blocker_node[blockers]=$2
    } else fail("unknown row: " $1)
    next
}
$1=="metric" && $2=="integrity_errors" { integrity=$3 }
$1=="attempt" {
    a=$2; attempt[a]=$0; akind[a]=$4; aclass[a]=$8; asize[a]=($6=="-" ? 0 : split($6,tmp,",")); end[a]=$10; duration[a]=$11
    valid[a]=($12=="completed" && $13 ~ /^(done|passed)$/ && $7=="-" && $10!="-" && $11!="-")
    if($7!="-") retried[$7]=1
}
$1=="span" && ($4!="completed" || $10=="external") { excluded[$3]=1 }
$1=="wave" { observed_wave[$2]=1 }
$1=="wave-ticket" { delivered[$3]=($6=="fully-verified" ? 1 : delivered[$3]) }
$1=="ticket" { if($8=="fully-verified") delivered[$2]=1 }
$1=="obligation" { observed_obligation[$2,$3,$4,$5]=$6 }
$1=="diagnostic" { report_diagnostic[$2 SUBSEP $3]=1 }
END {
    if(bad) exit 2
    n=split("version scope graph ownership obligations capacity capacity_epoch admission_ref environment retry_policy retry_low retry_high retry_reason",required," ")
    for(i=1;i<=n;i++) if(!(required[i] in meta)) fail("missing metadata: " required[i])
    if(meta["version"]!="1" || !token(meta["scope"]) || !token(meta["environment"]) || meta["retry_policy"]!="separate-allowance") fail("unsupported version/scope/environment/retry policy")
    for(i=1;i<=3;i++) {
        k=(i==1 ? "graph" : (i==2 ? "ownership" : "obligations"))
        if(meta[k]!="complete" && meta[k]!="unknown") fail("invalid completeness: " k)
        if(meta[k]=="unknown") unavailable("unknown-" k,"declaration")
    }
    if(meta["capacity"]!="unknown" && (!integer(meta["capacity"]) || meta["capacity"]>128)) fail("capacity must be 0..128 or unknown")
    if(!integer(meta["capacity_epoch"]) || meta["capacity_epoch"]+0>now) fail("invalid/future capacity epoch")
    if(!integer(meta["retry_low"]) || !integer(meta["retry_high"]) || meta["retry_low"]+0>meta["retry_high"]+0) fail("invalid retry allowance")
    if(meta["capacity"]=="unknown" || meta["capacity"]==0 || meta["admission_ref"]=="unknown") unavailable("unavailable-admission-capacity","declaration")
    if(!waves) unavailable("missing-wave-scope","declaration")
    for(w in scope) if(!(w in observed_wave)) unavailable("unknown-wave",w)
    if(integrity=="" || integrity+0!=0) unavailable("report-integrity-errors","observations")
    for(k in report_diagnostic) {
        split(k,tmp,SUBSEP)
        if(tmp[1] ~ /^(verification-unavailable|incomplete-declaration|incomplete-publication|malformed-record)$/) unavailable(tmp[1],tmp[2])
    }
    for(k in edge) {
        split(k,tmp,SUBSEP)
        if(!(tmp[1] in kind) || !(tmp[2] in kind)) fail("edge references unknown node")
        indegree[tmp[2]]++
    }
    for(k in obligation) {
        id=obligation[k]
        if(!(id in kind) || kind[id]!="gate" || !(obligation_wave[k] in scope)) fail("obligation must name a scoped shared gate")
        if(stg[id]!="mixed" && stg[id]!=obligation_stage[k]) fail("gate stage disagrees with obligation")
        obligations_for[id]++
        if(!(k in observed_obligation)) unavailable("unobserved-obligation",id)
        else if(observed_obligation[k]=="passed") unavailable("already-satisfied-obligation",id)
    }
    for(k in observed_obligation) {
        split(k,tmp,SUBSEP)
        if((tmp[1] in scope) && observed_obligation[k]!="passed" && !(k in obligation)) unavailable("unrepresented-outstanding-obligation",tmp[2])
    }
    for(i=1;i<=blockers;i++) {
        if(!(blocker_node[i] in kind)) fail("external blocker references unknown node")
        print blocker[i]
    }
    # Select at most twenty most recent comparable eligible observations per node.
    # Ties break on attempt ID; time of rendering never ages samples out.
    for(i=1;i<=nodes;i++) {
        id=ids[i]
        if(kind[id]=="gate" && !obligations_for[id]) unavailable("gate-without-obligations",id)
        if(cls[id]=="unknown" || env[id]=="unknown" || env[id]!=meta["environment"]) unavailable("unknown-or-mismatched-class-environment",id)
        n=split(members[id],tmp,",")
        for(j=1;j<=n;j++) if(delivered[tmp[j]]) unavailable("already-delivered-member",tmp[j])
        count=0; lo=0; hi=0
        for(j=1;j<=20;j++) {
            best=""
            for(a in sample_stage) {
                if(selected[id,a] || !valid[a] || retried[a] || excluded[a] || akind[a]!=kind[id] || aclass[a]!=cls[id] || asize[a]!=size[id] || sample_stage[a]!=stg[id] || sample_env[a]!=env[id]) continue
                if(best=="" || end[a]+0>end[best]+0 || (end[a]+0==end[best]+0 && a<best)) best=a
            }
            if(best=="") break
            selected[id,best]=1; count++
            d=duration[best]+0
            if(count==1 || d<lo) lo=d
            if(count==1 || d>hi) hi=d
            print "sample",id,best,d,kind[id],cls[id],size[id],stg[id],env[id],end[best]
        }
        print "cohort",id,count,(count<3 ? "sparse" : "observed-range-no-confidence"),kind[id],cls[id],size[id],stg[id],env[id]
        print "entity",id,purpose[id],members[id],(count ? lo : "-"),(count ? hi : "-")
        if(!count) unavailable("no-comparable-completed-samples",id)
        low[id]=lo; high[id]=hi; total+=lo
    }
    # Topological levels only, no worker selection, assignment or execution.
    done_count=0; maxlevel=0
    while(done_count<nodes) {
        progressed=0
        for(i=1;i<=nodes;i++) {
            id=ids[i]
            if(visited[id] || indegree[id]>0) continue
            visited[id]=1; done_count++; progressed=1
            level[id]=max(level[id],1); maxlevel=max(maxlevel,level[id])
            path[id]+=low[id]; critical=max(critical,path[id])
            level_count[level[id]]++; level_max[level[id]]=max(level_max[level[id]],high[id])
            for(j=1;j<=nodes;j++) if(edge[id,ids[j]]) {
                child=ids[j]; indegree[child]--; path[child]=max(path[child],path[id]); level[child]=max(level[child],level[id]+1)
            }
        }
        if(!progressed) fail("dependency/ownership cycle")
    }
    print "estimate","scope",meta["scope"]
    print "estimate","capacity",meta["capacity"]
    print "estimate","retry_policy",meta["retry_policy"]
    print "estimate","retry_allowance_low",meta["retry_low"]
    print "estimate","retry_allowance_high",meta["retry_high"]
    print "estimate","retry_reason",meta["retry_reason"]
    print "estimate","scenario","observed-min-max-level-batches"
    print "estimate","assumptions","whole remaining entities; fixed admitted slots; stable declared environment; retry-free attempt envelopes plus one future allowance; no confidence claim"
    lower=upper="-"
    if(!missing) {
        slots=meta["capacity"]+0
        lower=now+max(critical,ceil(total/slots))+meta["retry_low"]
        upper=now+meta["retry_high"]
        for(i=1;i<=maxlevel;i++) upper+=ceil(level_count[i]/slots)*level_max[i]
        if(upper>999999999999999) fail("scenario epoch exceeds supported range")
        lower=sprintf("%.0f",lower); upper=sprintf("%.0f",upper)
    }
    print "estimate","status",(missing ? "unavailable" : (blockers ? "conditional-external-blockers" : "scenario"))
    print "estimate","lower_epoch",lower
    print "estimate","upper_epoch",upper
    print "estimate","full_completion_upper_epoch",(blockers ? "-" : upper)
    print "estimate","external_blockers",blockers+0
}
