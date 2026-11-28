#!/usr/bin/env bash
# Tests for stop-verify.sh, using fake gradlew scripts instead of real builds.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../../.githooks/lib/testlib.sh
source "$here/../../.githooks/lib/testlib.sh"
hook="$here/stop-verify.sh"

repo=$(make_repo)
trap 'rm -rf "$repo"' EXIT
mkdir -p "$repo/server/src/main/java" "$repo/android/app" "$repo/docs"
fake_gradlew() { # fake_gradlew <module> <exit-code>
    printf '#!/usr/bin/env bash\necho "gradle $* in %s" >> "%s/calls.log"\necho "compilation failed in %s"\nexit %s\n' \
        "$1" "$repo" "$1" "$2" > "$repo/$1/gradlew"
    chmod +x "$repo/$1/gradlew"
}
fake_gradlew server 0
fake_gradlew android 0
echo "# docs" > "$repo/docs/README.md"
echo "calls.log" > "$repo/.gitignore"
git -C "$repo" add .
git -C "$repo" commit -q -m "chore: initial commit"

run() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$repo" "$hook"; }
calls() { cat "$repo/calls.log" 2>/dev/null; }
reset_calls() { rm -f "$repo/calls.log"; }

expect_pass "clean tree runs nothing" run '{"stop_hook_active":false}'
expect_pass "no gradle call on a clean tree" test -z "$(calls)"

echo "changed" >> "$repo/docs/README.md"
expect_pass "docs-only change runs nothing" run '{"stop_hook_active":false}'
expect_pass "no gradle call for docs-only change" test -z "$(calls)"
git -C "$repo" checkout -q -- docs/README.md

echo "class A {}" > "$repo/server/src/main/java/A.java"
expect_pass "server change with passing build" run '{"stop_hook_active":false}'
expect_output_contains "gradle --quiet --console=plain test in server" "server change runs the server unit tests" calls
android_not_built() { ! grep -q "in android" "$repo/calls.log"; }
expect_pass "android was not built for a server-only change" android_not_built
reset_calls

fake_gradlew server 1
expect_status 2 "server change with failing build blocks the stop" run '{"stop_hook_active":false}'
expect_output_contains "compilation failed in server" "failure output is reported" run '{"stop_hook_active":false}'
reset_calls
expect_pass "stop_hook_active skips the check" run '{"stop_hook_active":true}'
expect_pass "no gradle call when stop_hook_active" test -z "$(calls)"
rm "$repo/server/src/main/java/A.java"
fake_gradlew server 0
git -C "$repo" checkout -q -- server/gradlew

echo "x" > "$repo/android/app/Main.kt"
fake_gradlew android 1
expect_status 2 "android change with failing build blocks the stop" run '{}'
expect_output_contains "testDebugUnitTest in android" "android change runs the Android unit tests" calls

finish
