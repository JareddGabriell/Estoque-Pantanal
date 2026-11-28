#!/usr/bin/env bash
# Rejects emoji in tracked files, file names and commit messages.
#
# What counts as emoji: any character with the Unicode property
# Emoji_Presentation (characters that render as emoji by default), plus
# U+FE0F (variation selector that forces emoji rendering) and U+20E3
# (combining keycap). Typographic symbols such as arrows, check marks,
# "<=", the middle dot or the em dash are text-presentation characters and
# are allowed.
#
# Exceptions: none. Binary files (as detected by git) are skipped because
# they are not text. Tests build emoji from byte escapes, so no tracked text
# file needs a literal emoji. Do not add path exceptions without a strict
# need, and document each one here if you do.
#
# Usage:
#   no-emoji.sh --tracked              check every tracked text file and path in the working tree
#   no-emoji.sh --file <path>          check one file, e.g. a commit message ("-" reads stdin)
#   no-emoji.sh --range <rev-range>    check every commit message in the range
#
# Exit status: 0 when clean, 1 when emoji are found, 2 on usage errors.
# Requires perl (shipped with Git for Windows and every Linux CI image).
set -euo pipefail
export LC_ALL=C.UTF-8

# scan <skip-comments 0|1> <label> [file]: reads the file (or stdin), prints
# "<label>:<line>: U+XXXX" for each offending line, exits 1 if any.
# Comment lines ("#...") are skipped only in message mode, because git strips them.
# shellcheck disable=SC2016 # Perl source: the $ variables belong to Perl, not to the shell.
readonly PERL_SCAN='
    use strict; no warnings;
    my $skip_comments = shift @ARGV;
    my $label = shift @ARGV;
    my $in = \*STDIN;
    if (@ARGV) { open($in, "<", $ARGV[0]) or die "no-emoji: cannot read $ARGV[0]\n" }
    my $found = 0;
    while (my $line = <$in>) {
        last if $skip_comments && $line =~ /^# -+ >8 -+$/;
        next if $skip_comments && $line =~ /^#/;
        if ($line =~ /([\p{Emoji_Presentation}\x{FE0F}\x{20E3}])/) {
            printf STDERR "  %s:%d: U+%04X\n", $label, $., ord($1);
            $found = 1;
        }
    }
    exit($found ? 1 : 0);
'

scan() { perl -CSD -e "$PERL_SCAN" "$@"; }

usage() {
    sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0" >&2
    exit 2
}

# add <command...>: runs the scan, appends its report to $report when it finds emoji.
report=""
add() {
    local out
    out=$("$@" 2>&1) && return 0
    report+="$out"$'\n'
}

fail() {
    echo "no-emoji: emoji found (the project allows no emoji, see AGENTS.md):" >&2
    printf '%s' "$1" >&2
    exit 1
}

[[ $# -ge 1 ]] || usage

case "$1" in
    --tracked)
        [[ $# -eq 1 ]] || usage
        root=$(git rev-parse --show-toplevel)
        cd "$root"
        # File names.
        add scan 0 "path" < <(git -c core.quotePath=false ls-files)
        # Contents of tracked text files; -I skips files git considers binary.
        while IFS= read -r -d '' path; do
            [[ -f $path ]] || continue
            add scan 0 "$path" "$path"
        done < <(git grep -I -z -l -e '' -- . || true)
        [[ -z $report ]] || fail "$report"
        ;;
    --file)
        [[ $# -eq 2 ]] || usage
        if [[ $2 == - ]]; then
            add scan 1 "stdin"
        else
            [[ -r $2 ]] || { echo "no-emoji: cannot read $2" >&2; exit 2; }
            add scan 1 "$2" "$2"
        fi
        [[ -z $report ]] || fail "$report"
        ;;
    --range)
        [[ $# -eq 2 ]] || usage
        commits=$(git rev-list "$2") || { echo "no-emoji: invalid range $2" >&2; exit 2; }
        for sha in $commits; do
            add scan 0 "commit ${sha:0:12}" < <(git log -1 --format=%B "$sha")
        done
        [[ -z $report ]] || fail "$report"
        ;;
    *)
        usage
        ;;
esac
