#!/usr/bin/env bash
# json_get <dotted.path>: reads JSON on stdin and prints the value at the path
# ("" when missing, "true"/"false" for booleans). Returns non-zero when no
# parser is available or the input is not valid JSON.
#
# Tries jq, then python3, then perl with JSON::PP, because no single one is
# guaranteed everywhere (Fedora splits JSON::PP out of perl; Git for Windows
# ships perl but not jq or python3). JSON_GET_BACKEND=jq|python3|perl forces
# one backend; the tests use it to cover every fallback.
json_get() {
    local path=$1 input backend=${JSON_GET_BACKEND:-}
    input=$(cat)
    if [[ ${backend:-jq} == jq ]] && command -v jq > /dev/null 2>&1; then
        printf '%s' "$input" | jq -r --arg p "$path" \
            'getpath($p | split(".")) | if . == null then "" else tostring end'
        return
    fi
    if [[ ${backend:-python3} == python3 ]] && command -v python3 > /dev/null 2>&1; then
        printf '%s' "$input" | python3 -I -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    value = value.get(key) if isinstance(value, dict) else None
if value is None:
    value = ""
elif isinstance(value, bool):
    value = "true" if value else "false"
sys.stdout.write(str(value))' "$path"
        return
    fi
    if [[ ${backend:-perl} == perl ]] && perl -MJSON::PP -e 1 > /dev/null 2>&1; then
        printf '%s' "$input" | perl -MJSON::PP -0777 -e '
            binmode STDOUT, ":encoding(UTF-8)";
            my $v = JSON::PP->new->decode(<STDIN>);
            for my $k (split /\./, $ARGV[0]) { $v = ref $v eq "HASH" ? $v->{$k} : undef }
            print !defined $v ? "" : JSON::PP::is_bool($v) ? ($v ? "true" : "false") : $v;' "$path"
        return
    fi
    echo "json_get: no JSON parser found (install jq or python3)" >&2
    return 127
}
