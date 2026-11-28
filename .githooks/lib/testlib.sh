#!/usr/bin/env bash
# Minimal assertion helpers shared by the *.test.sh files.
# Source it from a test, call the helpers, then call `finish` last.
set -uo pipefail
export LC_ALL=C.UTF-8
# Hooks may run with these set by git; the throwaway repositories must not inherit them.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY

TESTS_RUN=0
TESTS_FAILED=0

# expect_status <expected-exit> <description> <command...>
# Runs the command (stdin is inherited) and compares its exit status.
expect_status() {
    local expected=$1 description=$2
    shift 2
    local output status
    output=$("$@" 2>&1)
    status=$?
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ $status -ne $expected ]]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "FAIL: ${description} (expected exit ${expected}, got ${status})"
        [[ -n $output ]] && printf '      %s\n' "$output"
    else
        echo "ok:   ${description}"
    fi
}

expect_pass() { expect_status 0 "$@"; }
expect_fail() { expect_status 1 "$@"; }

# expect_output_contains <needle> <description> <command...>
expect_output_contains() {
    local needle=$1 description=$2
    shift 2
    local output
    output=$("$@" 2>&1)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ $output != *"$needle"* ]]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "FAIL: ${description} (output does not contain \"${needle}\")"
        printf '      %s\n' "$output"
    else
        echo "ok:   ${description}"
    fi
}

# in_dir <dir> <command...>: runs the command inside <dir>, in a subshell.
in_dir() {
    local dir=$1
    shift
    (cd "$dir" && "$@")
}

# pipe_to <text> <command...>: feeds <text> plus a newline to the command's stdin.
pipe_to() {
    local text=$1
    shift
    printf '%s\n' "$text" | "$@"
}

# make_repo: creates a throwaway git repository, cds into it and prints its path.
# The caller is responsible for removing it (use a trap).
make_repo() {
    local dir
    dir=$(mktemp -d)
    git -C "$dir" init -q -b main
    git -C "$dir" config user.name "Test User"
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config commit.gpgsign false
    git -C "$dir" config core.hooksPath /dev/null
    printf '%s\n' "$dir"
}

# commit_with_message <repo> <message>: creates an empty commit with that full message.
commit_with_message() {
    git -C "$1" commit -q --allow-empty -m "$2"
}

finish() {
    echo "${TESTS_RUN} run, ${TESTS_FAILED} failed"
    [[ $TESTS_FAILED -eq 0 ]]
}
