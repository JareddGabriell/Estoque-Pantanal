#!/usr/bin/env bash
# Claude Code PreToolUse hook (Write|Edit|MultiEdit): blocks edits to files that
# must never change once they are tracked by git.
#
# Usage (from .claude/settings.json):
#   protect-tracked-file.sh flyway   blocks server/src/main/resources/db/migration/V*.sql
#   protect-tracked-file.sh room     blocks android/**/schemas/**.json
#
# Reads the hook input JSON on stdin and uses tool_input.file_path.
# "Tracked" means present in the git index (committed or staged). New,
# untracked files can still be written.
# Exit 0 allows the tool call; exit 2 blocks it and shows stderr to Claude.
#
# LANDMINE: this only covers Claude's file tools. A shell command (sed -i, mv,
# redirection) or a human editor can still change the file. Review catches those.
set -uo pipefail

kind=${1:-}
case "$kind" in
    flyway)
        is_protected() { [[ $1 == server/src/main/resources/db/migration/V*.sql ]]; }
        reason="is a Flyway migration already tracked by git. Migrations are immutable once committed; add a new V<next>__<description>.sql instead (see .claude/rules/server-architecture.md)."
        ;;
    room)
        is_protected() { [[ $1 == android/*/schemas/*.json ]]; }
        reason="is an exported Room schema already tracked by git. Exported schemas are generated history; bump the database version and let Room export a new file instead (see .claude/rules/android-architecture.md)."
        ;;
    *)
        echo "protect-tracked-file: unknown kind '${kind}' (expected flyway or room)" >&2
        exit 2
        ;;
esac

# shellcheck source=lib/json-get.sh
source "$(dirname "$0")/lib/json-get.sh"
if ! file_path=$(json_get tool_input.file_path); then
    # Fail closed: an unreadable input must not silently allow the edit.
    echo "protect-tracked-file: could not parse the hook input; refusing the edit" >&2
    exit 2
fi
[[ -n $file_path ]] || exit 0

root=${CLAUDE_PROJECT_DIR:-$(pwd)}
# --full-name gives the path relative to the repository root and prints
# nothing for untracked files or paths outside the repository.
tracked=$(git --literal-pathspecs -C "$root" ls-files --full-name -- "$file_path" 2>/dev/null | head -n 1)
[[ -n $tracked ]] || exit 0

if is_protected "$tracked"; then
    echo "BLOCKED: ${tracked} ${reason}" >&2
    exit 2
fi
exit 0
