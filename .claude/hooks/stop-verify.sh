#!/usr/bin/env bash
# Claude Code Stop hook: when the working tree has uncommitted changes under
# server/src or android/, runs a fast compile and unit-test check of that
# module before Claude may finish. On failure it exits 2, which feeds the
# build output back to Claude so it keeps working.
#
# Respects stop_hook_active: when Claude is already continuing because of this
# hook, it exits 0 so the session cannot loop.
#
# Commands per module:
#   server:  ./gradlew test               (unit tests; Phase 3 moves integration tests out of it)
#   android: ./gradlew testDebugUnitTest  (compiles and runs JVM unit tests of Android modules)
#
# LANDMINE: only uncommitted changes (including untracked files) are detected.
# Committed work is covered by CI, not by this hook.
set -uo pipefail

# shellcheck source=lib/json-get.sh
source "$(dirname "$0")/lib/json-get.sh"
active=$(json_get stop_hook_active 2>/dev/null) || active=""
[[ $active == true ]] && exit 0

root=${CLAUDE_PROJECT_DIR:-$(pwd)}
cd "$root" || exit 0

changed() {
    [[ -n $(git status --porcelain --untracked-files=all -- "$1" 2>/dev/null) ]]
}

failures=""
run_check() {
    local module=$1
    shift
    local output
    if ! output=$(cd "$module" && "$@" 2>&1); then
        failures+="${module}: '$*' failed. Last lines of output:"$'\n'
        failures+=$(tail -n 40 <<< "$output")$'\n\n'
    fi
}

if changed server/src; then
    run_check server ./gradlew --quiet --console=plain test
fi
if changed android; then
    run_check android ./gradlew --quiet --console=plain testDebugUnitTest
fi

if [[ -n $failures ]]; then
    printf 'Stop hook: the fast build check failed. Fix it before finishing.\n\n%s' "$failures" >&2
    exit 2
fi
exit 0
