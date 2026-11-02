#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_until.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper --until times"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


# Assert that, at clock time 'now' ('HH MM'), '--until' time 'time_until' locks
# for 'minutes' minutes.
function check_until() {
    local now="${1}"
    local time_until="${2}"
    local minutes="${3}"
    local nam="until_${time_until}_at_${now// /}"

    CTB_FAKE_NOW="${now}"
    export CTB_FAKE_NOW
    run_ctb "${nam//:/}" start --until "${time_until}" Reddit
    assert_status 0 "${nam}"
    assert_lines \
        "${CTB_FAKE_LOG}" \
        "${nam}: locked ${minutes} min" \
        "[-start][Reddit][-lock][${minutes}]"
}


# Assert that '--until' rejects 'time_until' without calling Cold Turkey.
function check_invalid() {
    local time_until="${1}"
    local nam="invalid_${time_until//[^A-Za-z0-9]/_}"

    CTB_FAKE_NOW="10 00"
    export CTB_FAKE_NOW
    run_ctb "${nam}" start --until "${time_until}" Reddit
    assert_status 1 "${nam}"
    assert_text_found \
        "${fil_err}" \
        "invalid time: '${time_until}'." \
        "${nam}: diagnostic"
    assert_lines "${CTB_FAKE_LOG}" "${nam}: no Cold Turkey call"
}


setup_test_env

print_section "24-hour times"
check_until "10 00" "17:30" 450
check_until "10 00" "9:00" 1380
check_until "10 00" "10:00" 1440
check_until "08 05" "08:09" 4
check_until "00 00" "23:59" 1439

print_section "12-hour times"
check_until "23 59" "12:00am" 1
check_until "11 00" "12:30pm" 90
check_until "13 00" "1:15pm" 15
check_until "09 30" "9:45AM" 15
check_until "00 00" "11:59pm" 1439

print_section "invalid times"
check_invalid "25:00"
check_invalid "12:60"
check_invalid "13:00pm"
check_invalid "0:30am"
check_invalid "7"
check_invalid "7:5"
check_invalid "noon"

print_section "clock failures"
unset CTB_FAKE_NOW
run_ctb date_fails start --until 17:30 Reddit
assert_status 1 "date_fails"
assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::calculate_minutes_until): failed to read the" \
    "date_fails: diagnostic"

assert_lines "${CTB_FAKE_LOG}" "date_fails: no Cold Turkey call"

CTB_FAKE_NOW="10:00"
export CTB_FAKE_NOW
run_ctb date_unexpected start --until 17:30 Reddit
assert_status 1 "date_unexpected"
assert_text_found \
    "${fil_err}" \
    "unexpected output from 'date': '10:00'." \
    "date_unexpected: diagnostic"

finish
