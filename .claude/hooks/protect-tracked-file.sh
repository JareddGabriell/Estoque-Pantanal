#!/usr/bin/env bash
# Claude Code PreToolUse hook (Write|Edit|MultiEdit): blocks edits to files
# that must never change once they are merged into main.
#
# Usage (from .claude/settings.json):
#   protect-tracked-file.sh flyway   protects server/src/main/resources/db/migration/V*.sql
#   protect-tracked-file.sh room     protects android/**/schemas/**.json
#
# Reads the hook input JSON on stdin and uses tool_input.file_path.
# A protected file is blocked when it exists in origin/main
# (git cat-file -e origin/main:<path>). On a feature branch, a new migration or
# schema stays editable, whether it is untracked, staged or committed, until it
# is merged.
#
# When origin/main is not available locally (no remote, never fetched), the
# hook cannot tell whether the file was merged, so it fails closed: edits to
# protected paths are blocked with a message to run `git fetch origin main`.
# Other paths are never affected.
#
# Exit 0 allows the tool call; exit 2 blocks it and shows stderr to Claude.
#
# LANDMINE: origin/main is only as fresh as the last fetch. A migration merged
# after your last fetch is still editable here until you fetch again.
# LANDMINE: this only covers Claude's file tools. A shell command (sed -i, mv,
# redirection) or a human editor can still change the file. Review catches those.
set -uo pipefail

readonly BASE_REF=refs/remotes/origin/main

kind=${1:-}
case "$kind" in
    flyway)
        is_protected() { [[ $1 == server/src/main/resources/db/migration/V*.sql ]]; }
        reason="is a Flyway migration already merged into main. Merged migrations are immutable; add a new V<next>__<description>.sql instead (see .claude/rules/server-architecture.md)."
        ;;
    room)
        is_protected() { [[ $1 == android/*/schemas/*.json ]]; }
        reason="is an exported Room schema already merged into main. Exported schemas are history; bump the database version and let Room export a new file instead (see .claude/rules/android-architecture.md)."
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

# to_posix <path>: converts a Windows path (C:\x) to a POSIX one under Git Bash.
to_posix() {
    if command -v cygpath > /dev/null 2>&1; then cygpath -u -- "$1"; else printf '%s\n' "$1"; fi
}

root=$(to_posix "${CLAUDE_PROJECT_DIR:-$(pwd)}")
top=$(git -C "$root" rev-parse --show-toplevel 2> /dev/null) || exit 0   # not a git repository
top=$(realpath -m -- "$(to_posix "$top")")

path=$(to_posix "$file_path")
[[ $path == /* ]] || path="$root/$path"
path=$(realpath -m -- "$path")
[[ $path == "$top"/* ]] || exit 0   # outside the repository
rel=${path#"$top"/}

is_protected "$rel" || exit 0

if ! git -C "$top" rev-parse --verify --quiet "${BASE_REF}^{commit}" > /dev/null; then
    echo "BLOCKED: cannot tell whether ${rel} is merged, because origin/main is not available locally. Run 'git fetch origin main' and try again." >&2
    exit 2
fi
if git -C "$top" cat-file -e "${BASE_REF}:${rel}" 2> /dev/null; then
    echo "BLOCKED: ${rel} ${reason}" >&2
    exit 2
fi
exit 0
