#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_confirm.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper pauses and confirmation"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


setup_test_env

# The 'sqlite3' stub and the script's settings reader both need Perl.
if \
    ! command -v perl > /dev/null 2>&1
then
    record_skip "confirmation: perl is not installed"
    finish
    exit $?
fi

print_section "pauses between Cold Turkey calls"
run_ctb delay_default start focus
assert_status 0 "delay_default"
assert_lines \
    "${CTB_FAKE_SLEEP_LOG}" \
    "delay_default: one pause between calls and one before the check" \
    "[2]" \
    "[2]"

CTB_DELAY="0.5"
export CTB_DELAY
run_ctb delay_fraction start focus
assert_status 0 "delay_fraction"
assert_lines \
    "${CTB_FAKE_SLEEP_LOG}" \
    "delay_fraction: 'CTB_DELAY' sets the pause" \
    "[0.5]" \
    "[0.5]"

CTB_DELAY="0"
run_ctb delay_zero start focus
assert_status 0 "delay_zero"
assert_lines "${CTB_FAKE_SLEEP_LOG}" "delay_zero: no pauses"
assert_lines \
    "${fil_out}" \
    "delay_zero: stdout" \
    "Started 2 blocks:" \
    "  Social Media" \
    "  News"

CTB_DELAY="soon"
run_ctb delay_invalid start focus
assert_status 1 "delay_invalid"
assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::validate_args): 'CTB_DELAY' must be a number of" \
    "delay_invalid: diagnostic"

assert_lines "${CTB_FAKE_LOG}" "delay_invalid: no Cold Turkey call"
unset CTB_DELAY

print_section "confirming started blocks"
run_ctb start_confirmed start --lock 30 focus
assert_status 0 "start_confirmed"
assert_lines \
    "${fil_out}" \
    "start_confirmed: stdout" \
    "Started 2 blocks, locked for 30 min:" \
    "  Social Media" \
    "  News"

assert_lines "${fil_err}" "start_confirmed: nothing on stderr"
assert_lines \
    "${CTB_FAKE_STATE}" \
    "start_confirmed: both blocks on" \
    "$(printf 'on\tSocial Media')" \
    "$(printf 'on\tNews')"

CTB_FAKE_DROP="News"
export CTB_FAKE_DROP
run_ctb start_dropped start focus
assert_status 1 "start_dropped"
assert_lines \
    "${fil_out}" \
    "start_dropped: success reported only for the confirmed block" \
    "Started 1 block:" \
    "  Social Media"

assert_text_found \
    "${fil_err}" \
    "$(
        printf '%s' \
            "error(ctb_helper.sh::start_blocks): block 'News' did not" \
            " start; run 'start' again for it."
    )" \
    "start_dropped: diagnostic"

assert_lines \
    "${CTB_FAKE_SLEEP_LOG}" \
    "start_dropped: settings read three times before giving up" \
    "[2]" \
    "[2]" \
    "[2]" \
    "[2]"

assert_lines \
    "${CTB_FAKE_OSA_LOG}" \
    "start_dropped: notification lists only the confirmed block" \
    "$(
        printf '%s' \
            '[-e][display notification "Started: Social Media"' \
            ' with title "Cold Turkey"]'
    )"
unset CTB_FAKE_DROP

CTB_FAKE_MISSING="Nope"
export CTB_FAKE_MISSING
run_ctb start_missing start Reddit Nope
assert_status 1 "start_missing"
assert_lines \
    "${fil_out}" \
    "start_missing: stdout" \
    "Started 1 block:" \
    "  Reddit"
assert_text_found \
    "${fil_err}" \
    "Cold Turkey has no block named 'Nope'." \
    "start_missing: diagnostic"

assert_lines \
    "${CTB_FAKE_SLEEP_LOG}" \
    "start_missing: a missing block is not read again" \
    "[2]" \
    "[2]"
unset CTB_FAKE_MISSING

CTB_FAKE_NOW="17 00"
export CTB_FAKE_NOW
run_ctb start_until start --until 5:30pm Reddit
assert_status 0 "start_until"
assert_lines \
    "${fil_out}" \
    "start_until: summary names the end time as given" \
    "Started 1 block, locked until 5:30pm:" \
    "  Reddit"
unset CTB_FAKE_NOW

print_section "confirming stopped blocks"
run_ctb stop_confirmed stop focus
assert_status 0 "stop_confirmed"
assert_lines \
    "${fil_out}" \
    "stop_confirmed: stdout" \
    "Stopped 2 blocks:" \
    "  Social Media" \
    "  News"

assert_lines "${fil_err}" "stop_confirmed: nothing on stderr"

CTB_FAKE_DROP="News"
export CTB_FAKE_DROP
run_ctb stop_dropped stop focus
assert_status 1 "stop_dropped"
assert_lines \
    "${fil_out}" \
    "stop_dropped: stdout" \
    "Stopped 1 block:" \
    "  Social Media"
assert_text_found \
    "${fil_err}" \
    "block 'News' is still on; it may be locked." \
    "stop_dropped: diagnostic"
unset CTB_FAKE_DROP

print_section "settings that cannot be read"
ctb_db_saved="${CTB_DB}"
CTB_DB="${TEST_DIR_CASE}/missing.db"
export CTB_DB
run_ctb db_missing start focus
assert_status 0 "db_missing"
assert_lines \
    "${fil_out}" \
    "db_missing: blocks reported as started" \
    "Started 2 blocks:" \
    "  Social Media" \
    "  News"

assert_text_found \
    "${fil_err}" \
    "$(
        printf '%s' \
            "note(ctb_helper.sh::start_blocks): could not read Cold" \
            " Turkey's settings to confirm that the blocks started."
    )" \
    "db_missing: note"

CTB_DB="${ctb_db_saved}"

CTB_FAKE_DB_FAIL=1
export CTB_FAKE_DB_FAIL
run_ctb db_fails stop focus
assert_status 0 "db_fails"
assert_lines \
    "${fil_out}" \
    "db_fails: blocks reported as stopped" \
    "Stopped 2 blocks:" \
    "  Social Media" \
    "  News"

assert_text_found \
    "${fil_err}" \
    "to confirm that the blocks stopped." \
    "db_fails: note"
unset CTB_FAKE_DB_FAIL

finish
