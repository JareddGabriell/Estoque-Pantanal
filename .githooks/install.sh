#!/usr/bin/env bash
# Points git at the versioned hooks in .githooks/ for this clone.
# Run once per clone: .githooks/install.sh
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

git config core.hooksPath .githooks
chmod +x .githooks/commit-msg .githooks/pre-push .githooks/checks/*.sh .githooks/run-tests.sh .claude/hooks/*.sh 2>/dev/null || true

missing=()
command -v perl > /dev/null 2>&1 || missing+=("perl (required by no-emoji.sh)")
if ! command -v jq > /dev/null 2>&1 && ! command -v python3 > /dev/null 2>&1; then
    missing+=("jq or python3 (required by the Claude Code hooks; on Windows install jq)")
fi
command -v betterleaks > /dev/null 2>&1 || missing+=("betterleaks 1.x (optional locally; pre-push skips the secret scan without it)")

echo "core.hooksPath set to .githooks for ${root}"
for item in "${missing[@]}"; do
    echo "missing: ${item}"
done
