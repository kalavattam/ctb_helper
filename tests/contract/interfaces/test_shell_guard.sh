#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_shell_guard.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper under non-Bash shells"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


# Assert that running 'ctb_helper.sh' with the command in 'arr_shell' exits 1
# with exactly the guard's message and calls no Cold Turkey command.
function check_refused() {
    local nam="${1}"
    local status

    shift 1
    fil_out="${TEST_DIR_CASE}/${nam}.out"
    fil_err="${TEST_DIR_CASE}/${nam}.err"
    : > "${CTB_FAKE_LOG}"

    if \
        "$@" "${CTB_HELPER}" start Reddit > "${fil_out}" 2> "${fil_err}"
    then
        status=0
    else
        status=$?
    fi

    if [[ "${status}" -eq 1 ]]; then
        record_pass "${nam}: refused with status 1"
    else
        record_fail "${nam}: expected status 1, got ${status}."
    fi

    assert_lines \
        "${fil_err}" \
        "${nam}: guard message only" \
        "error(shell): this script must be run under Bash >= 3.2."

    assert_lines "${CTB_FAKE_LOG}" "${nam}: no Cold Turkey call"
}


setup_test_env
n_checked=0

print_section "non-Bash shells"
for shell in dash zsh ksh mksh; do
    if \
        command -v "${shell}" > /dev/null 2>&1
    then
        check_refused "${shell}" "${shell}"
        n_checked=$(( n_checked + 1 ))
    else
        record_skip "${shell}: not installed"
    fi
done

if \
    command -v busybox > /dev/null 2>&1
then
    check_refused busybox_sh busybox sh
    n_checked=$(( n_checked + 1 ))
else
    record_skip "busybox sh: not installed"
fi

# On macOS, 'sh' is Bash in POSIX mode, which the guard rightly accepts.
if \
    sh -c '[ -z "${BASH_VERSION:-}" ]'
then
    check_refused sh sh
    n_checked=$(( n_checked + 1 ))
else
    record_skip "sh: 'sh' is Bash on this host"
fi

if [[ "${n_checked}" -eq 0 ]]; then
    record_warn "no non-Bash shell was available to check"
fi

finish
