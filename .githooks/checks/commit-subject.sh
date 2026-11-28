#!/usr/bin/env bash
# Validates commit subjects against the project's Conventional Commits rules.
#
# Rules (see .claude/rules/commits-and-prs.md):
#   - format: <type>(<scope>)!: <description>   (scope and "!" are optional)
#   - type is one of ALLOWED_TYPES below
#   - scope is lowercase letters, digits and hyphens
#   - description is not empty, does not start with a space, does not end
#     with a period or whitespace
#   - the whole subject is at most 72 characters
#
# Usage:
#   commit-subject.sh --subject "<subject>"   check one subject (also PR titles)
#   commit-subject.sh --file <msg-file>       check the subject of a commit message file
#   commit-subject.sh --range <rev-range>     check every non-merge commit, e.g. origin/main..HEAD
#
# Exit status: 0 when every subject is valid, 1 when any is invalid, 2 on usage errors.
set -euo pipefail
export LC_ALL=C.UTF-8

readonly MAX_LENGTH=72
readonly ALLOWED_TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
readonly PATTERN="^(${ALLOWED_TYPES})(\([a-z0-9][a-z0-9-]*\))?!?: [^ ](.*[^. ])?$"

usage() {
    sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0" >&2
    exit 2
}

# check_subject <subject> [<label>]
check_subject() {
    local subject=$1 label=${2:-subject}
    local ok=0
    if [[ ! $subject =~ $PATTERN ]]; then
        echo "commit-subject: ${label}: not a valid Conventional Commits subject: \"${subject}\"" >&2
        echo "  expected <type>(<scope>)!: <description>, type in: ${ALLOWED_TYPES//|/, }; no trailing period" >&2
        ok=1
    fi
    if (( ${#subject} > MAX_LENGTH )); then
        echo "commit-subject: ${label}: subject is ${#subject} characters, the limit is ${MAX_LENGTH}: \"${subject}\"" >&2
        ok=1
    fi
    return "$ok"
}

[[ $# -eq 2 ]] || usage

case "$1" in
    --subject)
        check_subject "$2"
        ;;
    --file)
        [[ -r $2 ]] || { echo "commit-subject: cannot read $2" >&2; exit 2; }
        # Git strips comment lines from the message, so the subject is the first non-comment line.
        subject=$(awk '!/^#/ { print; exit }' "$2")
        check_subject "$subject"
        ;;
    --range)
        commits=$(git rev-list --no-merges "$2") || { echo "commit-subject: invalid range $2" >&2; exit 2; }
        status=0
        for sha in $commits; do
            check_subject "$(git log -1 --format=%s "$sha")" "commit ${sha:0:12}" || status=1
        done
        exit "$status"
        ;;
    *)
        usage
        ;;
esac
