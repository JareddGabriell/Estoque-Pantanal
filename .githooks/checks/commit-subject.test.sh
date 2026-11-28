#!/usr/bin/env bash
# Tests for commit-subject.sh.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/testlib.sh
source "$here/../lib/testlib.sh"
check="$here/commit-subject.sh"

# Accepted subjects.
expect_pass "plain type" "$check" --subject "docs: add testing guide"
expect_pass "type with scope" "$check" --subject "feat(sync): add push endpoint"
expect_pass "breaking change marker" "$check" --subject "refactor(server)!: rename sync cursor field"
expect_pass "hyphenated scope" "$check" --subject "fix(core-domain): round order quantity up"
expect_pass "every allowed type" bash -c '
    for t in feat fix docs style refactor perf test build ci chore revert; do
        "$1" --subject "$t: do something" || exit 1
    done' _ "$check"
expect_pass "exactly 72 characters" "$check" --subject "feat: $(printf 'a%.0s' $(seq 66))"
expect_pass "non-ASCII counted as characters" "$check" --subject "fix(android): show \"Contagem concluída\" in toast"

# Rejected subjects.
expect_fail "73 characters" "$check" --subject "feat: $(printf 'a%.0s' $(seq 67))"
expect_fail "unknown type" "$check" --subject "feature: add login"
expect_fail "missing type" "$check" --subject "add login screen"
expect_fail "uppercase type" "$check" --subject "Feat: add login"
expect_fail "missing space after colon" "$check" --subject "feat:add login"
expect_fail "empty description" "$check" --subject "feat: "
expect_fail "trailing period" "$check" --subject "feat: add login."
expect_fail "trailing whitespace" "$check" --subject "feat: add login "
expect_fail "uppercase scope" "$check" --subject "feat(Sync): add push"
expect_fail "empty scope" "$check" --subject "feat(): add push"
expect_fail "git default revert subject" "$check" --subject 'Revert "feat: add login"'
expect_fail "fixup subject" "$check" --subject "fixup! feat: add login"
expect_status 2 "usage error without arguments" "$check"

# --file mode: subject is the first non-comment line.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "${repo:-}"' EXIT
printf '# comment from git\nfeat(server): add ping endpoint\n\nBody line.\n' > "$tmp/good"
printf 'Added the ping endpoint\n\nBody.\n' > "$tmp/bad"
expect_pass "--file accepts a valid message" "$check" --file "$tmp/good"
expect_fail "--file rejects an invalid message" "$check" --file "$tmp/bad"

# --range mode.
repo=$(make_repo)
commit_with_message "$repo" "chore: initial commit"
base=$(git -C "$repo" rev-parse HEAD)
commit_with_message "$repo" "feat(sync): add outbox table"
commit_with_message "$repo" "fix(sync): retry on timeout"
expect_pass "--range with valid subjects" bash -c 'cd "$1" && "$2" --range "$3..HEAD"' _ "$repo" "$check" "$base"
commit_with_message "$repo" "WIP stuff"
expect_fail "--range with one invalid subject" bash -c 'cd "$1" && "$2" --range "$3..HEAD"' _ "$repo" "$check" "$base"
expect_output_contains "WIP stuff" "--range names the bad subject" bash -c 'cd "$1" && "$2" --range "$3..HEAD"' _ "$repo" "$check" "$base"
expect_status 2 "--range with an invalid range" bash -c 'cd "$1" && "$2" --range "nope..HEAD"' _ "$repo" "$check"

finish
