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
# presets files, 'tool/' holds stubs for Cold Turkey, 'date', 'osascript', and
# an editor, and 'format/' holds an input and expected output for
# 'format_md_quotes.sh'.
dir_fix="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
dir_pre="${dir_fix}/presets"
dir_tol="${dir_fix}/tool"
dir_fmt="${dir_fix}/format"

# Remove stale outputs so that regeneration is idempotent.
rm -rf "${dir_pre}" "${dir_tol}" "${dir_fmt}"
mkdir -p "${dir_pre}" "${dir_tol}" "${dir_fmt}"


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
# brackets, to the file named by 'CTB_FAKE_LOG', and it fails for any block
# named in the colon-separated list 'CTB_FAKE_FAIL'.
cat > "${dir_tol}/cold_turkey" << 'EOM'
#!/bin/sh
: "${CTB_FAKE_LOG:?CTB_FAKE_LOG must name the call log}"
for arg in "$@"; do
    printf '[%s]' "${arg}" >> "${CTB_FAKE_LOG}"
done
printf '\n' >> "${CTB_FAKE_LOG}"
case ":${CTB_FAKE_FAIL:-}:" in
    *":${2:-}:"*) exit 1 ;;
esac
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

chmod +x \
    "${dir_tol}/cold_turkey" \
    "${dir_tol}/date" \
    "${dir_tol}/osascript" \
    "${dir_tol}/editor"


# Write Markdown with straight quotes in prose, in code, in link targets, in
# HTML, in a fence, and in a reference definition, ending without a line feed.
# The delimiter is quoted because the body holds backticks and backslashes that
# must reach the file as written.
cat > "${dir_fmt}/input.txt" << 'EOM'
# Heading with "double" and 'single' quotes
Plain "double quotes" and 'single quotes' in prose.
Apostrophes: Kris's repo, don't, it's.
Quote after bracket ("inside") and ['inside'].
Inline code keeps `"straight"` and `'straight'` quotes, and ``a `"b"` c``.
Escaped \"quotes\" stay straight.
A [link "text"](https://example.com/a'b "title") and <a id="x"></a>.
Already curly “double” and ‘single’ quotes stay; a dash —"quoted" opens.
- List item with "quotes".
| Cell "one" | Cell 'two' |

```bash
echo "fenced code keeps 'quotes'"
```

[ref]: https://example.com "Reference title"
EOM
printf '%s' 'last "line" without newline' >> "${dir_fmt}/input.txt"

# Write the expected conversion of 'input.txt', authored by hand.
cat > "${dir_fmt}/expected.txt" << 'EOM'
# Heading with “double” and ‘single’ quotes
Plain “double quotes” and ‘single quotes’ in prose.
Apostrophes: Kris’s repo, don’t, it’s.
Quote after bracket (“inside”) and [‘inside’].
Inline code keeps `"straight"` and `'straight'` quotes, and ``a `"b"` c``.
Escaped \"quotes\" stay straight.
A [link “text”](https://example.com/a'b "title") and <a id="x"></a>.
Already curly “double” and ‘single’ quotes stay; a dash —“quoted” opens.
- List item with “quotes”.
| Cell “one” | Cell ‘two’ |

```bash
echo "fenced code keeps 'quotes'"
```

[ref]: https://example.com "Reference title"
EOM
printf '%s' 'last “line” without newline' >> "${dir_fmt}/expected.txt"
