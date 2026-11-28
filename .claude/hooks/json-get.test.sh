#!/usr/bin/env bash
# Tests for lib/json-get.sh, once per available backend.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../../.githooks/lib/testlib.sh
source "$here/../../.githooks/lib/testlib.sh"
# shellcheck source=lib/json-get.sh
source "$here/lib/json-get.sh"

payload='{"tool_input":{"file_path":"/repo/server/V1__init.sql"},"stop_hook_active":true,"n":{"off":false}}'
get() { printf '%s' "$payload" | JSON_GET_BACKEND=$1 json_get "$2"; }
is() { [[ $(get "$1" "$2") == "$3" ]]; }

invalid_json_fails() { ! (printf 'not json' | JSON_GET_BACKEND=$1 json_get a 2> /dev/null); }

backends=()
command -v jq > /dev/null 2>&1 && backends+=(jq)
command -v python3 > /dev/null 2>&1 && backends+=(python3)
perl -MJSON::PP -e 1 > /dev/null 2>&1 && backends+=(perl)
expect_pass "at least one JSON backend is available" test "${#backends[@]}" -gt 0

for b in "${backends[@]}"; do
    expect_pass "$b: nested string" is "$b" tool_input.file_path /repo/server/V1__init.sql
    expect_pass "$b: true boolean" is "$b" stop_hook_active true
    expect_pass "$b: false boolean" is "$b" n.off false
    expect_pass "$b: missing key is empty" is "$b" tool_input.nope ""
    expect_pass "$b: path through a non-object is empty" is "$b" tool_input.file_path.x ""
    expect_pass "$b: invalid JSON fails" invalid_json_fails "$b"
done
echo "backends tested: ${backends[*]}"

finish
