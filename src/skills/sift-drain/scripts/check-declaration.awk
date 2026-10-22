# Bounded verification mapping in config.yaml. Never evaluate YAML as shell.
# Output only after the entire selected mapping has passed validation.
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function uncomment(s,   i,c,q,out) {
  q=""; out=""
  for (i=1; i<=length(s); i++) {
    c=substr(s,i,1)
    if (q!="") {
      out=out c
      if (c==q) {
        if (q==sq && substr(s,i+1,1)==sq) { out=out sq; i++ }
        else q=""
      }
    } else {
      if (c=="#" && (i==1 || substr(s,i-1,1) ~ /[[:space:]]/)) break
      if (c==sq || c=="\"") q=c
      out=out c
    }
  }
  if (q!="") bad=1
  return trim(out)
}
function scalar(s,allow_empty,   first,last) {
  s=trim(s); first=substr(s,1,1); last=substr(s,length(s),1)
  if (first==sq) {
    if (last!=sq || length(s)<2) { bad=1; return "" }
    s=substr(s,2,length(s)-2); gsub(sq sq,"\001",s)
    if (index(s,sq)) bad=1
    gsub(/\001/,sq,s)
  } else if (first=="\"") {
    if (last!="\"" || length(s)<2) { bad=1; return "" }
    s=substr(s,2,length(s)-2)
    if (s ~ /[\\"]/) bad=1
  } else if (s ~ /[][{}#,:&*!|>"\047]/) bad=1
  if ((!allow_empty && s=="") || s ~ /[^ -~]/) bad=1
  return s
}
function emit(k,s) { rows=rows k "\t" s "\n" }
function list(k,s,   i,c,q,part,n) {
  if (substr(s,1,1)!="[" || substr(s,length(s),1)!="]") { bad=1; return }
  s=substr(s,2,length(s)-2); q=""; part=""; n=0
  for(i=1;i<=length(s)+1;i++) {
    c=substr(s,i,1)
    if (q!="") {
      part=part c
      if(c==q) {
        if(q==sq && substr(s,i+1,1)==sq) { part=part sq; i++ }
        else q=""
      }
    } else if(c=="," || i>length(s)) {
      if(trim(part)!="") { emit(k,scalar(part,k=="command")); n++ }
      else bad=1
      part=""
    } else { if(c==sq || c=="\"") q=c; part=part c }
  }
  if(q!="" || n==0) bad=1
}
BEGIN { sq=sprintf("%c",39); wanted=ENVIRON["SIFT_CHECK_ID"] }
/^[[:space:]]*(#.*)?$/ { next }
/^verification:[[:space:]]*(#.*)?$/ {
  if (seen++) bad=1
  inside=1; selected=0; next
}
/^verification:/ { bad=1; inside=0; selected=0; next }
/^[^[:space:]]/ { inside=0; selected=0; next }
inside {
  if ($0 ~ /^  [A-Za-z0-9][A-Za-z0-9_.-]*:[[:space:]]*(#.*)?$/) {
    key=$0; sub(/^  /,"",key); sub(/:.*/,"",key)
    if(ids[key]++) bad=1
    selected=(key==wanted)
    if(selected) found=1
    next
  }
  if(!selected) next
  if($0 !~ /^    [a-z_]+:[[:space:]]+/) { bad=1; next }
  line=substr($0,5); key=line; sub(/:.*/,"",key)
  sub(/^[^:]*:[[:space:]]*/,"",line); line=uncomment(line)
  if(keys[key]++) bad=1
  if(key=="inputs" || key=="environment" || key=="command") list(key,line)
  else if(key ~ /^(complete|required|stage|scope|cwd|platform)$/) emit(key,scalar(line))
  else bad=1
}
END {
  if(bad || !found) exit 1
  for (i=1;i<=9;i++) {
    split("complete required stage scope cwd inputs environment platform command",required," ")
    if(!keys[required[i]]) exit 1
  }
  printf "%s",rows
}
