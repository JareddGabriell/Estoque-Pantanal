#!/usr/bin/env bash
# Tests for protect-tracked-file.sh.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../../.githooks/lib/testlib.sh
source "$here/../../.githooks/lib/testlib.sh"
hook="$here/protect-tracked-file.sh"

mig=server/src/main/resources/db/migration
schemas=android/app/schemas/app.beverageinventory.data.AppDatabase

# Repository whose main branch (mirrored as origin/main) has V1 and schema 1.
repo=$(make_repo)
no_remote=$(make_repo)
trap 'rm -rf "$repo" "$no_remote"' EXIT
mkdir -p "$repo/$mig" "$repo/$schemas"
echo "create table supplier ();" > "$repo/$mig/V1__create_supplier.sql"
echo '{"formatVersion": 1}' > "$repo/$schemas/1.json"
echo "quarkus.http.port=8080" > "$repo/server/src/main/resources/application.properties"
git -C "$repo" add .
git -C "$repo" commit -q -m "chore: initial commit"
git -C "$repo" update-ref refs/remotes/origin/main HEAD

# Feature branch: V2 committed on the branch only, V3 staged only, V4 untracked.
git -C "$repo" switch -q -c feature/2-product
echo "create table product ();" > "$repo/$mig/V2__create_product.sql"
echo '{"formatVersion": 1}' > "$repo/$schemas/2.json"
git -C "$repo" add .
git -C "$repo" commit -q -m "feat(server): add product table"
echo "create table count ();" > "$repo/$mig/V3__create_count.sql"
echo '{"formatVersion": 1}' > "$repo/$schemas/3.json"
git -C "$repo" add .
echo "create table count_item ();" > "$repo/$mig/V4__create_count_item.sql"

# run <repo> <kind> <file_path>: feeds a Write hook payload for that path.
run() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$3" \
        | CLAUDE_PROJECT_DIR="$1" "$hook" "$2"
}
run_relative() { (cd "$repo" && run "$repo" flyway "$1"); }
run_raw() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$repo" "$hook" "$2"; }

# Flyway.
expect_status 2 "blocks a migration present in origin/main" run "$repo" flyway "$repo/$mig/V1__create_supplier.sql"
expect_output_contains "BLOCKED: $mig/V1__create_supplier.sql is a Flyway migration already merged" \
    "names the blocked file" run "$repo" flyway "$repo/$mig/V1__create_supplier.sql"
expect_pass "allows a migration committed only on the branch" run "$repo" flyway "$repo/$mig/V2__create_product.sql"
expect_pass "allows a migration that is only in the index" run "$repo" flyway "$repo/$mig/V3__create_count.sql"
expect_pass "allows a new untracked migration" run "$repo" flyway "$repo/$mig/V4__create_count_item.sql"
expect_pass "allows a migration that does not exist yet" run "$repo" flyway "$repo/$mig/V5__new.sql"
rm "$repo/$mig/V1__create_supplier.sql"
expect_status 2 "blocks recreating a merged migration deleted locally" run "$repo" flyway "$repo/$mig/V1__create_supplier.sql"
git -C "$repo" checkout -q -- "$mig/V1__create_supplier.sql"
expect_status 2 "blocks a relative path to a merged migration" run_relative "$mig/V1__create_supplier.sql"
expect_status 2 "blocks a path with dot segments" run "$repo" flyway "$repo/server/../$mig/V1__create_supplier.sql"
expect_pass "allows other files present in origin/main" run "$repo" flyway "$repo/server/src/main/resources/application.properties"
expect_pass "flyway kind ignores Room schemas" run "$repo" flyway "$repo/$schemas/1.json"

# Room.
expect_status 2 "blocks a Room schema present in origin/main" run "$repo" room "$repo/$schemas/1.json"
expect_pass "allows a Room schema committed only on the branch" run "$repo" room "$repo/$schemas/2.json"
expect_pass "allows a Room schema that is only in the index" run "$repo" room "$repo/$schemas/3.json"
expect_pass "room kind ignores migrations" run "$repo" room "$repo/$mig/V1__create_supplier.sql"

# origin/main not available: protected paths fail closed, other paths are unaffected.
mkdir -p "$no_remote/$mig"
echo "create table supplier ();" > "$no_remote/$mig/V1__create_supplier.sql"
git -C "$no_remote" add .
git -C "$no_remote" commit -q -m "chore: initial commit"
expect_status 2 "without origin/main, blocks a protected path" run "$no_remote" flyway "$no_remote/$mig/V1__create_supplier.sql"
expect_output_contains "git fetch origin main" "without origin/main, says how to fix it" run "$no_remote" flyway "$no_remote/$mig/V9__new.sql"
expect_pass "without origin/main, allows other paths" run "$no_remote" flyway "$no_remote/README.md"

# Input handling.
expect_pass "allows paths outside the repository" run "$repo" flyway "/etc/hostname"
expect_pass "allows a payload without file_path" run_raw '{"tool_input":{}}' flyway
expect_status 2 "fails closed on invalid JSON" run_raw "not json" flyway
expect_status 2 "rejects an unknown kind" run_raw "{}" other

finish
