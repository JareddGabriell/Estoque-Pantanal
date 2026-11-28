#!/usr/bin/env bash
# Runs every *.test.sh for the git hook checks and the Claude Code hooks.
# Used by the pre-push hook and by the CI policy job (.github/workflows/ci.yml).
set -uo pipefail

root=$(git rev-parse --show-toplevel)
status=0
shopt -s nullglob
for test in "$root"/.githooks/checks/*.test.sh "$root"/.claude/hooks/*.test.sh; do
    name=${test#"$root"/}
    if output=$(bash "$test" 2>&1); then
        echo "PASS ${name} ($(tail -n 1 <<< "$output"))"
    else
        status=1
        echo "FAIL ${name}"
        printf '%s\n' "$output" | grep -v '^ok:' | sed 's/^/    /'
    fi
done
exit "$status"
