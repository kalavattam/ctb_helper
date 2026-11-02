#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_shell_source.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="repository shell source"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


# Constructs that need Bash newer than 3.2, as extended regular expressions.
# Each is matched only on lines that are not comments.
arr_newer_bash=(
    'declare -[a-zA-Z]*[gA]'
    'local -[a-zA-Z]*A'
    '(^|[^a-z_])(mapfile|readarray)([^a-z_]|$)'
    '\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)'
    "%\\("
    '\[\[ -v '
    'wait -n'
    '&>>'
)

setup_test_env
n_files=0

print_section "maintained shell files"
while IFS= read -r fil; do
    n_files=$(( n_files + 1 ))
    rel="${fil#"${ROOT_REPO}/"}"
    nam="$(basename "${fil}")"

    if \
        "${TEST_BASH}" -n "${fil}" 2> "${TEST_DIR_CASE}/parse.err"
    then
        record_pass "${rel}: parses"
    else
        record_fail "${rel}: does not parse; see '${TEST_DIR_CASE}/parse.err'."
    fi

    if \
        grep -q -x -F -- "# Script: ${nam}" "${fil}"
    then
        record_pass "${rel}: header names '${nam}'"
    else
        record_fail "${rel}: header lacks '# Script: ${nam}'."
    fi

    # Skip this file, whose pattern list would match itself.
    if [[ "${nam}" == "$(basename "${BASH_SOURCE[0]}")" ]]; then
        continue
    fi

    for patn in "${arr_newer_bash[@]}"; do
        if \
            grep -v -E '^[[:space:]]*#' "${fil}" | grep -q -E -- "${patn}"
        then
            record_fail "${rel}: uses a construct newer than Bash 3.2: ${patn}"
        fi
    done
done < <(
    find "${ROOT_REPO}/bin" "${ROOT_REPO}/dev" "${ROOT_REPO}/tests" \
        -type f -name '*.sh' -print | LC_ALL=C sort
)

# Prove that the scan inspected files rather than passing vacuously.
if [[ "${n_files}" -ge 2 ]]; then
    record_pass "inspected ${n_files} shell files"
else
    record_fail "inspected ${n_files} shell files; expected at least 2."
fi

finish
