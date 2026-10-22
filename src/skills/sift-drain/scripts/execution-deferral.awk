# A recorded explicit grant, not an inference from an event's deferred outcome.
BEGIN {FS=OFS="\t"}
NR==1 {if($0!="# Compatibility deferral v1") bad=1;next}
NR==2 {if($0!="") bad=1;next}
{
    if(NF!=2 || $2=="" || $2 ~ /[^ -~]/ || seen[$1]++) bad=1
    if($1 !~ /^(run_id|wave_id|check_id|stage|scope|authorization_ref|authorization|reason|outstanding_obligation|config_cksum)$/) bad=1
    value[$1]=$2
}
END {
    if(NR!=12 || bad || value["run_id"]!=ENVIRON["SIFT_DEFER_RUN"] ||
       value["wave_id"]!=ENVIRON["SIFT_DEFER_WAVE"] || value["check_id"]!=ENVIRON["SIFT_DEFER_CHECK"] ||
       value["stage"]!="compatibility" || value["scope"]!=ENVIRON["SIFT_DEFER_SCOPE"] ||
       value["config_cksum"]!=ENVIRON["SIFT_DEFER_CONFIG"]) exit 1
    print value["authorization_ref"],value["authorization"],value["reason"],value["outstanding_obligation"]
}
