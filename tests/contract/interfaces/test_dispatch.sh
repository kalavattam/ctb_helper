#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_dispatch.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper Cold Turkey calls"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


setup_test_env

print_section "starting blocks"
run_ctb start_lock start --lock 90 focus
assert_status 0 "start_lock"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_lock: Cold Turkey calls" \
    "[-start][Social Media][-lock][90]" \
    "[-start][News][-lock][90]"

assert_lines \
    "${fil_out}" \
    "start_lock: stdout" \
    "started: Social Media (locked 90 min)" \
    "started: News (locked 90 min)"

assert_lines \
    "${CTB_FAKE_OSA_LOG}" \
    "start_lock: notification" \
    "$(
        printf '%s' \
            '[-e][display notification "Started: Social Media, News' \
            ' (locked 90 min)" with title "Cold Turkey"]'
    )"

run_ctb start_password start -p 's3cret word' Reddit
assert_status 0 "start_password"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_password: Cold Turkey call" \
    "[-start][Reddit][-password][s3cret word]"

assert_lines \
    "${fil_out}" \
    "start_password: stdout" \
    "started: Reddit (password-locked)"

run_ctb start_unlocked start Reddit
assert_status 0 "start_unlocked"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_unlocked: Cold Turkey call without lock options" \
    "[-start][Reddit]"

assert_lines "${fil_out}" "start_unlocked: stdout" "started: Reddit"

print_section "stopping blocks"
run_ctb stop_preset stop focus
assert_status 0 "stop_preset"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "stop_preset: Cold Turkey calls" \
    "[-stop][Social Media]" \
    "[-stop][News]"

assert_lines \
    "${fil_out}" \
    "stop_preset: stdout" \
    "stopped: Social Media" \
    "stopped: News"

assert_lines "${CTB_FAKE_OSA_LOG}" "stop_preset: no notification"

print_section "Cold Turkey failures"
CTB_FAKE_FAIL="News"
export CTB_FAKE_FAIL
run_ctb start_one_fails start focus Reddit
assert_status 1 "start_one_fails"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_one_fails: every block is still attempted" \
    "[-start][Social Media]" \
    "[-start][News]" \
    "[-start][Reddit]"

assert_lines \
    "${fil_out}" \
    "start_one_fails: success reported only for started blocks" \
    "started: Social Media" \
    "started: Reddit"

assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::start_blocks): Cold Turkey failed to start block" \
    "start_one_fails: diagnostic"

assert_lines \
    "${CTB_FAKE_OSA_LOG}" \
    "start_one_fails: notification lists only started blocks" \
    "$(
        printf '%s' \
            '[-e][display notification "Started: Social Media, Reddit"' \
            ' with title "Cold Turkey"]'
    )"

run_ctb stop_one_fails stop focus
assert_status 1 "stop_one_fails"
assert_text_found \
    "${fil_err}" \
    "Cold Turkey failed to stop block 'News'; it may be locked." \
    "stop_one_fails: diagnostic"

CTB_FAKE_FAIL="Social Media:News"
run_ctb start_all_fail start focus
assert_status 1 "start_all_fail"
assert_lines "${fil_out}" "start_all_fail: no success reported"
assert_lines "${CTB_FAKE_OSA_LOG}" "start_all_fail: no notification"
unset CTB_FAKE_FAIL

print_section "notification text"
run_ctb notify_escaped start 'Say "hi"' 'back\slash'
assert_status 0 "notify_escaped"
assert_lines \
    "${CTB_FAKE_OSA_LOG}" \
    "notify_escaped: quotes and backslashes escaped for AppleScript" \
    "$(
        printf '%s' \
            '[-e][display notification "Started: Say \"hi\", back\\slash"' \
            ' with title "Cold Turkey"]'
    )"

print_section "finding Cold Turkey"
ctb_bin_saved="${CTB_BIN}"
CTB_BIN="${TEST_DIR_CASE}/missing_cold_turkey"
run_ctb bin_not_executable start Reddit
assert_status 1 "bin_not_executable"
assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::find_ct_bin): 'CTB_BIN' is not an executable file:" \
    "bin_not_executable: diagnostic"

assert_lines "${CTB_FAKE_LOG}" "bin_not_executable: no Cold Turkey call"

# Unset 'CTB_BIN' only when no default install exists, so that this case can
# never run a real Cold Turkey.
dir_mac="/Applications/Cold Turkey Blocker.app/Contents/MacOS"
dir_win="Program Files/Cold Turkey"
if \
    [[ -e "${dir_mac}/Cold Turkey Blocker" \
        || -e "/c/${dir_win}/Cold Turkey Blocker.exe" \
        || -e "/mnt/c/${dir_win}/Cold Turkey Blocker.exe" ]]
then
    record_skip "bin_not_found: Cold Turkey is installed on this host"
else
    unset CTB_BIN
    run_ctb bin_not_found start Reddit
    assert_status 1 "bin_not_found"
    assert_text_found \
        "${fil_err}" \
        "Cold Turkey Blocker not found in a default install location;" \
        "bin_not_found: diagnostic"
fi

CTB_BIN="${ctb_bin_saved}"
export CTB_BIN

finish
