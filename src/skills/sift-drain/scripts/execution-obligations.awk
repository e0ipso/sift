# Enumerate the current bounded verification mapping. Detailed per-check parsing
# remains check-declaration.awk's responsibility. Reject unaccounted structure.
/^[[:space:]]*(#.*)?$/ {next}
/^verification:[[:space:]]*(#.*)?$/ {if(seen++) bad=1; inside=1; next}
/^verification:/ {bad=1; next}
/^[^[:space:]]/ {inside=0; next}
inside {
    if($0 ~ /^  [A-Za-z0-9][A-Za-z0-9_.-]*:[[:space:]]*(#.*)?$/) {
        id=$0;sub(/^  /,"",id);sub(/:.*/,"",id)
        if(ids[id]++) bad=1
    } else if($0 !~ /^    [a-z_]+:[[:space:]]+/ || id=="") bad=1
}
END {if(!seen || bad) exit 1; for(id in ids) print id}
