# Bounded flat record grammar. mode=input reads CLI key=value operands;
# mode=record validates serialized Markdown. All diagnostics go to stderr via
# a portable pipe, rather than the non-POSIX /dev/stderr awk extension.
function fail(message) {
    print "error: execution event: " message | "cat >&2"
    close("cat >&2")
    bad = 1
    exit 2
}
function token(s) { return length(s) <= 128 && s ~ /^[[:alnum:]][[:alnum:]_.-]*$/ }
function integer(s) { return length(s) <= 15 && s ~ /^(0|[1-9][0-9]*)$/ }
function need(key) { if (!(key in value)) fail("missing field: " key) }
function identity(key) {
    if (!(key in value)) {
        if (mode == "record") fail("missing field: " key)
        value[key] = value["event_id"]
    }
}
function ticket(s,   p, digits) {
    p = ENVIRON["SIFT_EVENT_PREFIX"] "-"
    if (substr(s, 1, length(p)) != p) return 0
    digits = substr(s, length(p) + 1)
    return length(digits) >= 4 && digits ~ /^[0-9]+$/
}
BEGIN {
    fields = "version event_id kind run_id actor actor_id timestamp wave_id wave sitting_id gate_id attempt_id retry_of members span_id activity duration outcome reason reason_detail wait_class work_class stage ticket_id origin_attempt_id origin_gate_id relation root_cause external_id evidence_ref check_id exit_status"
    nfields = split(fields, order, " ")
    for (i = 1; i <= nfields; i++) known[order[i]] = 1
    q = sprintf("%c", 39)
}
{
    if (mode == "record") {
        if (NR == 1) { if ($0 != "---") fail("missing opening fence"); next }
        if ($0 == "---" && !closed) { closed = NR; next }
        if (closed) {
            if (NR == closed + 1 && $0 == "") next
            if (NR == closed + 2 && $0 == "# Execution event") next
            fail("unexpected record body")
        }
        sep = index($0, ": ")
        key = substr($0, 1, sep - 1)
        raw = substr($0, sep + 2)
        if (!sep || length(raw) < 2 || substr(raw, 1, 1) != q || substr(raw, length(raw), 1) != q)
            fail("expected quoted scalar")
        raw = substr(raw, 2, length(raw) - 2)
        s = ""
        for (j = 1; j <= length(raw); j++) {
            c = substr(raw, j, 1)
            if (c == q) {
                if (substr(raw, ++j, 1) != q) fail("unescaped quote")
            }
            s = s c
        }
    } else {
        sep = index($0, "=")
        if (!sep) fail("expected key=value")
        key = substr($0, 1, sep - 1); s = substr($0, sep + 1)
    }
    if (!(key in known)) fail("unknown field: " key)
    if (key in value) fail("duplicate field: " key)
    if (!length(s) || length(s) > 4096 || s ~ /[^[:print:]]/) fail("invalid scalar: " key)
    value[key] = s
}
END {
    if (bad) exit 2
    if (mode == "record" && (!closed || NR != closed + 2)) fail("incomplete record")
    need("version"); need("event_id"); need("kind"); need("run_id"); need("actor"); need("timestamp")
    if (value["version"] != "1") fail("unsupported version")
    for (key in value) {
        if ((key ~ /_id$/ && key != "external_id") || key == "retry_of" || key == "root_cause")
            if (!token(value[key])) fail("invalid identity: " key)
    }
    if (value["actor"] !~ /^(coordinator|worker|gate|reviewer|helper)$/) fail("invalid actor")
    if (!integer(value["timestamp"])) fail("invalid timestamp")
    if ("duration" in value && !integer(value["duration"])) fail("invalid duration")
    if ("wave" in value && (!integer(value["wave"]) || value["wave"] == "0")) fail("invalid wave")
    if ("exit_status" in value && (!integer(value["exit_status"]) || value["exit_status"] + 0 > 255)) fail("invalid exit_status")
    if ("activity" in value && value["activity"] !~ /^(preparation|orientation|implementation|verification|review|landing|cleanup)$/) fail("invalid activity")
    if ("work_class" in value && value["work_class"] !~ /^(product|infrastructure|unknown)$/) fail("invalid work_class")
    if ("stage" in value && value["stage"] !~ /^(development|compatibility)$/) fail("invalid stage")
    if ("wait_class" in value && value["wait_class"] !~ /^(external|actionable)$/) fail("invalid wait_class")
    if ("reason" in value && value["reason"] !~ /^(dependencies|write-ownership|resource-admission|provider-limits|user-input|setup-failure|command-failure|interrupted|retry|repair|missing-evidence|changed-inputs|unchanged-inputs|unavailable-environment|authorized-deferral|other)$/) fail("invalid reason")
    if ("outcome" in value && value["outcome"] !~ /^(done|failed|blocked|wontfix|superseded|cancelled|passed|reused|invalidated|deferred)$/) fail("invalid outcome")
    if ("relation" in value && value["relation"] !~ /^(follow-up|repair)$/) fail("invalid relation")
    if ("ticket_id" in value && !ticket(value["ticket_id"])) fail("invalid ticket_id")
    if ("members" in value && value["members"] != "-") {
        n = split(value["members"], member, ",")
        for (i = 1; i <= n; i++) {
            if (!ticket(member[i]) || seen[member[i]]++) fail("invalid or duplicate member")
        }
    }

    kind = value["kind"]
    if (kind == "run-start" || kind == "run-resume") {
        # The run_id is its own identity, independent of each publication.
    } else if (kind == "run-interrupt") need("reason")
    else if (kind == "run-end") need("outcome")
    else if (kind == "wave-start") { identity("wave_id"); need("wave") }
    else if (kind == "wave-end") { need("wave_id"); need("outcome") }
    else if (kind == "sitting") {
        identity("sitting_id"); need("wave_id"); need("members")
        if (value["members"] == "-") fail("sitting requires members")
    } else if (kind == "gate") { identity("gate_id"); need("wave_id") }
    else if (kind == "attempt-start") {
        identity("attempt_id"); need("wave_id"); need("members")
        if (("sitting_id" in value) == ("gate_id" in value)) fail("attempt requires exactly one sitting_id or gate_id")
        if ("sitting_id" in value && value["members"] == "-") fail("ticket attempt requires members")
        if ("retry_of" in value && value["retry_of"] == value["attempt_id"]) fail("self retry")
    } else if (kind == "attempt-interrupt") { need("attempt_id"); need("reason") }
    else if (kind == "attempt-resume") need("attempt_id")
    else if (kind == "attempt-end") { need("attempt_id"); need("outcome") }
    else if (kind == "span-start") { identity("span_id"); need("attempt_id"); need("activity") }
    else if (kind == "span-end") { need("span_id"); need("attempt_id"); need("duration"); need("outcome") }
    else if (kind == "wait-start") {
        identity("span_id"); need("attempt_id"); need("reason"); need("wait_class")
        if (value["reason"] !~ /^(dependencies|write-ownership|resource-admission|provider-limits|user-input)$/) fail("invalid wait reason")
    } else if (kind == "wait-end") { need("span_id"); need("attempt_id"); need("duration") }
    else if (kind == "ticket-outcome" || kind == "landed") {
        need("attempt_id"); need("ticket_id")
        if (kind == "ticket-outcome") {
            need("outcome")
            if (value["outcome"] !~ /^(done|failed|blocked|wontfix|superseded|cancelled)$/) fail("invalid ticket outcome")
        } else need("evidence_ref")
    } else if (kind == "link") {
        need("relation"); need("ticket_id")
        if (!("origin_attempt_id" in value) && !("origin_gate_id" in value)) fail("link requires origin")
    } else if (kind == "check") {
        need("attempt_id"); need("check_id"); need("stage"); need("outcome"); need("evidence_ref")
        if (value["outcome"] !~ /^(passed|failed|reused|invalidated|deferred)$/) fail("invalid check outcome")
        if (value["outcome"] ~ /^(passed|failed)$/) {
            need("exit_status")
            if ((value["outcome"] == "passed") != (value["exit_status"] == "0")) fail("check outcome disagrees with exit_status")
        } else need("reason")
    } else fail("unknown kind")

    # Membership belongs only to declarations, never an inferred timestamp
    # group. Cross-record subset/ref/terminal checks belong to reconstruction.
    if ("members" in value && kind != "sitting" && kind != "attempt-start") fail("members require a declaration")
    if ("retry_of" in value && kind != "attempt-start") fail("retry_of requires attempt-start")
    if ("sitting_id" in value && "gate_id" in value) fail("conflicting parents")
    if ("reason" in value && value["reason"] == "other") need("reason_detail")
    if ("ticket_id" in value && "members" in value && !seen[value["ticket_id"]]) fail("ticket_id outside members")
    if (emit == "fields") {
        for (i = 1; i <= nfields; i++) {
            key = order[i]
            if (key in value) print key "\t" value[key]
        }
    }
    if (emit == "record") {
        print "---"
        for (i = 1; i <= nfields; i++) {
            key = order[i]
            if (!(key in value)) continue
            s = value[key]; gsub(q, q q, s)
            print key ": " q s q
        }
        print "---\n\n# Execution event"
    }
}
