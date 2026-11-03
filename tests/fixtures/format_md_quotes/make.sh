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


# Resolve generated paths relative to this fixture root. 'format/' holds an
# input and expected output for 'format_md_quotes.sh'.
dir_fix="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
dir_fmt="${dir_fix}/format"

# Remove stale outputs so that regeneration is idempotent.
rm -rf "${dir_fmt}"
mkdir -p "${dir_fmt}"


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
