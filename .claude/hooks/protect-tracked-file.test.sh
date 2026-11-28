#!/usr/bin/env bash
# Tests for protect-tracked-file.sh.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../../.githooks/lib/testlib.sh
source "$here/../../.githooks/lib/testlib.sh"
hook="$here/protect-tracked-file.sh"

repo=$(make_repo)
trap 'rm -rf "$repo"' EXIT
mig=server/src/main/resources/db/migration
schemas=android/app/schemas/app.beverageinventory.data.AppDatabase
mkdir -p "$repo/$mig" "$repo/$schemas"
echo "create table supplier ();" > "$repo/$mig/V1__create_supplier.sql"
echo '{"formatVersion": 1}' > "$repo/$schemas/1.json"
echo "quarkus.http.port=8080" > "$repo/server/src/main/resources/application.properties"
git -C "$repo" add .
echo "create table product ();" > "$repo/$mig/V2__create_product.sql"
echo '{"formatVersion": 1}' > "$repo/$schemas/2.json"

# run <kind> <file_path>: feeds a Write hook payload for that path.
run() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$2" \
        | CLAUDE_PROJECT_DIR="$repo" "$hook" "$1"
}

expect_status 2 "blocks a tracked migration" run flyway "$repo/$mig/V1__create_supplier.sql"
expect_output_contains "BLOCKED: $mig/V1__create_supplier.sql" "names the blocked file" run flyway "$repo/$mig/V1__create_supplier.sql"
expect_pass "allows a new untracked migration" run flyway "$repo/$mig/V2__create_product.sql"
expect_pass "allows other tracked server files" run flyway "$repo/server/src/main/resources/application.properties"
expect_pass "flyway kind ignores Room schemas" run flyway "$repo/$schemas/1.json"
expect_status 2 "blocks a tracked Room schema" run room "$repo/$schemas/1.json"
expect_pass "allows a new untracked Room schema" run room "$repo/$schemas/2.json"
expect_pass "room kind ignores migrations" run room "$repo/$mig/V1__create_supplier.sql"
expect_pass "allows paths outside the repository" run flyway "/etc/hostname"
expect_status 2 "blocks a relative path to a tracked migration" bash -c '
    cd "$1" && printf "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"%s\"}}" "$2" | CLAUDE_PROJECT_DIR="$1" "$3" flyway' \
    _ "$repo" "$mig/V1__create_supplier.sql" "$hook"
expect_pass "allows a payload without file_path" bash -c 'echo "{\"tool_input\":{}}" | "$1" flyway' _ "$hook"
expect_status 2 "fails closed on invalid JSON" bash -c 'echo "not json" | "$1" flyway' _ "$hook"
expect_status 2 "rejects an unknown kind" bash -c 'echo "{}" | "$1" other' _ "$hook"

finish
