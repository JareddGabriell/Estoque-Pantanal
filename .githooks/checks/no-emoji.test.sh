#!/usr/bin/env bash
# Tests for no-emoji.sh.
# Emoji are built from UTF-8 byte escapes so this file itself contains none.
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/testlib.sh
source "$here/../lib/testlib.sh"
check="$here/no-emoji.sh"

beer=$(printf '\xf0\x9f\x8d\xba')          # U+1F37A beer mug
check_mark_button=$(printf '\xe2\x9c\x85') # U+2705
star=$(printf '\xe2\xad\x90')              # U+2B50
heart_vs16=$(printf '\xe2\x9d\xa4\xef\xb8\x8f') # U+2764 U+FE0F
flag_br=$(printf '\xf0\x9f\x87\xa7\xf0\x9f\x87\xb7') # regional indicators B R
arrow=$(printf '\xe2\x86\x92')             # U+2192, typographic, allowed
middle_dot=$(printf '\xc2\xb7')            # U+00B7, allowed
check_mark=$(printf '\xe2\x9c\x93')        # U+2713, text check mark, allowed
em_dash=$(printf '\xe2\x80\x94')           # U+2014, allowed

tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "${repo:-}"' EXIT
file() { printf '%s\n' "$2" > "$tmp/$1"; printf '%s\n' "$tmp/$1"; }

# --file mode.
expect_pass "plain ASCII" "$check" --file "$(file a "feat: add login")"
expect_pass "typographic symbols" "$check" --file "$(file b "a ${arrow} b ${middle_dot} c <= d ${check_mark} ${em_dash} e")"
expect_pass "Portuguese accents" "$check" --file "$(file c "Contagem concluída, ação necessária")"
expect_fail "emoji pictograph" "$check" --file "$(file d "feat: add beer ${beer}")"
expect_fail "emoji check mark button" "$check" --file "$(file e "done ${check_mark_button}")"
expect_fail "star emoji" "$check" --file "$(file f "nice ${star}")"
expect_fail "text symbol forced to emoji with VS16" "$check" --file "$(file g "love ${heart_vs16}")"
expect_fail "flag" "$check" --file "$(file h "made in ${flag_br}")"
expect_output_contains "U+1F37A" "report names the code point" "$check" --file "$(file i "x ${beer}")"
expect_pass "emoji only in git comment lines of a message" "$check" --file "$(file j $'feat: x\n# '"${beer}")"
expect_fail "stdin input" bash -c 'printf "%s\n" "$2" | "$1" --file -' _ "$check" "title ${beer}"
expect_status 2 "usage error without arguments" "$check"

# --tracked mode.
repo=$(make_repo)
printf 'hello %s\n' "$arrow" > "$repo/README.md"
printf '\x00\x01binary %s\n' "$beer" > "$repo/blob.bin"
git -C "$repo" add README.md blob.bin
expect_pass "--tracked: clean text, emoji only inside a binary file" bash -c 'cd "$1" && "$2" --tracked' _ "$repo" "$check"
printf 'untracked %s\n' "$beer" > "$repo/untracked.txt"
expect_pass "--tracked ignores untracked files" bash -c 'cd "$1" && "$2" --tracked' _ "$repo" "$check"
mkdir -p "$repo/docs"
printf 'line one\nline two %s\n' "$star" > "$repo/docs/guide.md"
git -C "$repo" add docs/guide.md
expect_fail "--tracked: emoji in a tracked file" bash -c 'cd "$1" && "$2" --tracked' _ "$repo" "$check"
expect_output_contains "docs/guide.md:2:" "--tracked reports file and line" bash -c 'cd "$1" && "$2" --tracked' _ "$repo" "$check"
git -C "$repo" rm -q --cached docs/guide.md
touch "$repo/name-${beer}.txt"
git -C "$repo" add "name-${beer}.txt"
expect_fail "--tracked: emoji in a file name" bash -c 'cd "$1" && "$2" --tracked' _ "$repo" "$check"
git -C "$repo" rm -q --cached "name-${beer}.txt"

# --range mode.
commit_with_message "$repo" "chore: initial commit"
base=$(git -C "$repo" rev-parse HEAD)
commit_with_message "$repo" "feat: add outbox ${arrow} worker"
expect_pass "--range with clean messages" bash -c 'cd "$1" && "$2" --range "$3..HEAD"' _ "$repo" "$check" "$base"
commit_with_message "$repo" "fix: retry ${beer}"
expect_fail "--range with an emoji in a message" bash -c 'cd "$1" && "$2" --range "$3..HEAD"' _ "$repo" "$check" "$base"

finish
