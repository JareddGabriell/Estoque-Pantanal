#!/usr/bin/env bash
# Rejects AI co-author trailers and AI attribution lines in commit messages,
# PR titles and PR bodies.
#
# A message fails when any line:
#   - is a Co-authored-by / Assisted-by / Generated-by / Helped-by trailer that
#     names an AI tool or vendor (Claude, Anthropic, OpenAI, Copilot, ...)
#   - contains an AI vendor noreply address (noreply@anthropic.com, ...)
#   - is a "Generated with/by <AI tool>" attribution line or links to claude.com/claude-code
# Mentioning a tool in normal prose (e.g. "configure Claude Code hooks") is allowed.
#
# Usage:
#   no-ai-coauthor.sh --file <path>       check a message file ("-" reads stdin)
#   no-ai-coauthor.sh --range <rev-range> check every commit message in the range
#
# Exit status: 0 when clean, 1 when attribution is found, 2 on usage errors.
set -euo pipefail
export LC_ALL=C.UTF-8

readonly AI_NAMES='claude|anthropic|openai|chatgpt|gpt-?[0-9]|copilot|gemini|bard|cursor|codeium|windsurf|devin|aider|tabnine|codewhisperer|amazon q|cody|deepseek|mistral|llama|(^|[^a-z])ai([^a-z]|$)|llm'
readonly TRAILER="^[[:space:]]*(co-authored-by|assisted-by|generated-by|helped-by|ai-assisted-by):.*(${AI_NAMES})"
readonly ADDRESS='noreply@anthropic\.com|@openai\.com|copilot@github\.com'
readonly GENERATED="generated (with|by|using) .*(${AI_NAMES})|claude\.com/claude-code"
readonly COMBINED="${TRAILER}|${ADDRESS}|${GENERATED}"

usage() {
    sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0" >&2
    exit 2
}

# check_message <label> [file]: checks the file, or stdin when no file is given.
check_message() {
    local label=$1 file=${2:--} hits
    # Drop git comment lines and everything below the "git commit -v" scissors line.
    hits=$(awk '/^# -+ >8 -+$/ { exit } !/^#/' "$file" | grep -Ein -e "$COMBINED" || true)
    if [[ -n $hits ]]; then
        echo "no-ai-coauthor: ${label}: AI co-author or attribution found (remove it):" >&2
        printf '  %s\n' "$hits" >&2
        return 1
    fi
}

[[ $# -eq 2 ]] || usage

case "$1" in
    --file)
        if [[ $2 == - ]]; then
            check_message "stdin"
        else
            [[ -r $2 ]] || { echo "no-ai-coauthor: cannot read $2" >&2; exit 2; }
            check_message "$2" "$2"
        fi
        ;;
    --range)
        commits=$(git rev-list "$2") || { echo "no-ai-coauthor: invalid range $2" >&2; exit 2; }
        status=0
        for sha in $commits; do
            git log -1 --format=%B "$sha" | check_message "commit ${sha:0:12}" || status=1
        done
        exit "$status"
        ;;
    *)
        usage
        ;;
esac
