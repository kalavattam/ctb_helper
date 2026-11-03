#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: make.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


# Require Bash >= 3.2 before doing any work; see 'docs/standards.md'.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "error(shell):" \
        "this script must be run under Bash >= 3.2." >&2
    exit 1
elif ((
    BASH_VERSINFO[0] < 3 || ( BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2 )
)); then
    echo "error($(basename "${BASH_SOURCE[0]}")):" \
        "this script requires Bash >= 3.2; current version is" \
        "'${BASH_VERSION}'." >&2
    exit 1
fi

# Run in safe mode, exiting on errors, unset variables, and pipe failures.
set -euo pipefail


# Resolve generated paths relative to this fixture root. 'presets/' holds
# presets files, and 'tool/' holds stubs for Cold Turkey, 'date', 'osascript',
# an editor, 'sleep', and 'sqlite3'.
dir_fix="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
dir_pre="${dir_fix}/presets"
dir_tol="${dir_fix}/tool"

# Remove stale outputs so that regeneration is idempotent.
rm -rf "${dir_pre}" "${dir_tol}"
mkdir -p "${dir_pre}" "${dir_tol}"


# Write a well-formed presets file.
cat > "${dir_pre}/basic.txt" << EOM
# Presets for ctb_helper tests.
focus = Social Media, News

deep = Social Media, News, Email
EOM

# Write a presets file that exercises comments, surrounding whitespace, tabs,
# lines without '=', a line without a name, empty entries, a repeated preset
# name, and a final line without a line feed.
printf '%s\n' \
    '   # An indented comment.' \
    'focus=Social Media,News' \
    "$(printf '\tdeep\t=\tEmail ,  Slack\t')" \
    'not a preset line' \
    '= Orphan' \
    'focus = Shopping, , News' \
    'empty =' \
    > "${dir_pre}/messy.txt"
printf '%s' 'last = Final Block   ' >> "${dir_pre}/messy.txt"

# Write a presets file that holds only comments and blank lines.
cat > "${dir_pre}/comments_only.txt" << EOM
# No presets are defined here.

# Not even this one.
EOM


# Write the Cold Turkey stub. It appends each call's arguments, each in
# brackets, to the file named by 'CTB_FAKE_LOG', prints a blank line as Cold
# Turkey does, and fails for any block named in the colon-separated list
# 'CTB_FAKE_FAIL'. When 'CTB_FAKE_STATE' names a file, the stub records there,
# as 'on' or 'off', a tab, and the name, the state that each '-start' or
# '-stop' leaves a block in. A block named in the colon-separated list
# 'CTB_FAKE_MISSING' does not exist and is never recorded, and a command for a
# block named in 'CTB_FAKE_DROP' is lost, which leaves that block in the other
# state.
cat > "${dir_tol}/cold_turkey" << 'EOM'
#!/bin/sh
: "${CTB_FAKE_LOG:?CTB_FAKE_LOG must name the call log}"
for arg in "$@"; do
    printf '[%s]' "${arg}" >> "${CTB_FAKE_LOG}"
done
printf '\n' >> "${CTB_FAKE_LOG}"
echo
case ":${CTB_FAKE_FAIL:-}:" in
    *":${2:-}:"*) exit 1 ;;
esac

if [ -z "${CTB_FAKE_STATE:-}" ] || [ "$#" -lt 2 ]; then
    exit 0
fi

case "$1" in
    -start) want=on; other=off ;;
    -stop) want=off; other=on ;;
    *) exit 0 ;;
esac

case ":${CTB_FAKE_MISSING:-}:" in
    *":$2:"*) exit 0 ;;
esac

case ":${CTB_FAKE_DROP:-}:" in
    *":$2:"*) want="${other}" ;;
esac

[ -f "${CTB_FAKE_STATE}" ] || : > "${CTB_FAKE_STATE}"
CTB_FAKE_NAME="$2" awk -F '\t' '$2 != ENVIRON["CTB_FAKE_NAME"]' \
    "${CTB_FAKE_STATE}" > "${CTB_FAKE_STATE}.tmp"
printf '%s\t%s\n' "${want}" "$2" >> "${CTB_FAKE_STATE}.tmp"
mv "${CTB_FAKE_STATE}.tmp" "${CTB_FAKE_STATE}"
exit 0
EOM

# Write the 'date' stub. It answers only the one format that 'ctb_helper.sh'
# uses, with the time in 'CTB_FAKE_NOW', and fails for any other call.
cat > "${dir_tol}/date" << 'EOM'
#!/bin/sh
if [ "$#" -eq 1 ] && [ "$1" = '+%H %M' ] && [ -n "${CTB_FAKE_NOW:-}" ]; then
    printf '%s\n' "${CTB_FAKE_NOW}"
    exit 0
fi
echo "error(date): unexpected test-stub call: $*" >&2
exit 1
EOM

# Write the 'osascript' stub, which records its arguments in the file named by
# 'CTB_FAKE_OSA_LOG' instead of showing a notification.
cat > "${dir_tol}/osascript" << 'EOM'
#!/bin/sh
: "${CTB_FAKE_OSA_LOG:?CTB_FAKE_OSA_LOG must name the call log}"
for arg in "$@"; do
    printf '[%s]' "${arg}" >> "${CTB_FAKE_OSA_LOG}"
done
printf '\n' >> "${CTB_FAKE_OSA_LOG}"
EOM

# Write the editor stub, which records its arguments in the file named by
# 'CTB_FAKE_EDITOR_LOG'.
cat > "${dir_tol}/editor" << 'EOM'
#!/bin/sh
: "${CTB_FAKE_EDITOR_LOG:?CTB_FAKE_EDITOR_LOG must name the call log}"
for arg in "$@"; do
    printf '[%s]' "${arg}" >> "${CTB_FAKE_EDITOR_LOG}"
done
printf '\n' >> "${CTB_FAKE_EDITOR_LOG}"
EOM

# Write the 'sleep' stub, which records its arguments in the file named by
# 'CTB_FAKE_SLEEP_LOG' instead of waiting.
cat > "${dir_tol}/sleep" << 'EOM'
#!/bin/sh
: "${CTB_FAKE_SLEEP_LOG:?CTB_FAKE_SLEEP_LOG must name the call log}"
for arg in "$@"; do
    printf '[%s]' "${arg}" >> "${CTB_FAKE_SLEEP_LOG}"
done
printf '\n' >> "${CTB_FAKE_SLEEP_LOG}"
EOM

# Write the 'sqlite3' stub. Given '-readonly' first, it prints the block states
# in the file named by 'CTB_FAKE_STATE' as Cold Turkey stores its settings:
# JSON whose bytes are each shifted up by 17, as 'CTB17' and hexadecimal
# digits. It fails when 'CTB_FAKE_DB_FAIL' is set, as for a database that
# cannot be opened.
cat > "${dir_tol}/sqlite3" << 'EOM'
#!/bin/sh
if [ -n "${CTB_FAKE_DB_FAIL:-}" ]; then
    echo "Error: unable to open database file" >&2
    exit 1
fi

if [ "${1:-}" != "-readonly" ]; then
    echo "error(sqlite3): expected '-readonly' first, got: $*" >&2
    exit 1
fi

: "${CTB_FAKE_STATE:?CTB_FAKE_STATE must name the block-state file}"
[ -f "${CTB_FAKE_STATE}" ] || : > "${CTB_FAKE_STATE}"
exec perl -MJSON::PP -e '
    my %blocks;
    open my $fh, q(<:encoding(UTF-8)), $ARGV[0] or exit 1;
    while (my $line = <$fh>) {
        chomp $line;
        my ($state, $nam) = split /\t/, $line, 2;
        next unless defined $nam;
        $blocks{$nam} = { enabled => $state eq q(on) ? q(true) : q(false) };
    }
    my $raw = JSON::PP->new->utf8->canonical->encode({ blocks => \%blocks });
    my $enc = join q(), map { chr((ord($_) + 17) % 256) } split //, $raw;
    print q(CTB17), unpack(q(H*), $enc), "\n";
' "${CTB_FAKE_STATE}"
EOM

chmod +x \
    "${dir_tol}/cold_turkey" \
    "${dir_tol}/date" \
    "${dir_tol}/osascript" \
    "${dir_tol}/editor" \
    "${dir_tol}/sleep" \
    "${dir_tol}/sqlite3"
