#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_cli_args.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper command-line arguments"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


# Assert that a help request exits 0, prints help to stderr, prints nothing to
# stdout, and calls no Cold Turkey command.
function check_help() {
    local nam="${1}"

    shift 1
    run_ctb "${nam}" "$@"
    assert_status 0 "${nam}"
    assert_text_found "${fil_err}" "Usage" "${nam}: help on stderr"
    assert_lines "${fil_out}" "${nam}: no stdout"
    assert_lines "${CTB_FAKE_LOG}" "${nam}: no Cold Turkey call"
}


# Assert that a rejected invocation exits 1, prints diagnostic 'text', and
# calls no Cold Turkey command.
function check_rejected() {
    local nam="${1}"
    local text="${2}"

    shift 2
    run_ctb "${nam}" "$@"
    assert_status 1 "${nam}"
    assert_text_found "${fil_err}" "${text}" "${nam}: diagnostic"
    assert_lines "${CTB_FAKE_LOG}" "${nam}: no Cold Turkey call"
}


setup_test_env

print_section "help requests"
check_help help_no_args
check_help help_word help
check_help help_short -h
check_help help_long --help
check_help help_after_start start -h focus
check_help help_after_stop stop --help

print_section "unknown commands and options"
check_rejected \
    unknown_command \
    "error(ctb_helper.sh::validate_args): unknown command: 'frob'." \
    frob

assert_text_found "${fil_err}" "Usage" "unknown_command: help on stderr"

check_rejected \
    unknown_option \
    "error(ctb_helper.sh::parse_args): unknown option/parameter passed:" \
    start \
    --bogus \
    focus

assert_text_found "${fil_err}" "'--bogus'." "unknown_option: exact token"
assert_text_found "${fil_err}" "Usage" "unknown_option: help on stderr"

check_rejected \
    missing_value \
    "error(ctb_helper.sh::parse_args): option '-l' requires a value." \
    start \
    -l

check_rejected \
    empty_value \
    "option '--lock' requires a value." \
    start \
    --lock \
    "" \
    focus

print_section "lock options"
check_rejected \
    lock_and_password \
    "specify at most one of '--lock', '--until', and '--password'." \
    start \
    -l \
    30 \
    -p \
    secret \
    focus

check_rejected \
    lock_and_until \
    "specify at most one of '--lock', '--until', and '--password'." \
    start \
    --lock \
    30 \
    --until \
    17:00 \
    focus

check_rejected \
    lock_zero \
    "'--lock' must be a positive whole number of minutes: '0'." \
    start \
    -l \
    0 \
    focus

check_rejected \
    lock_fraction \
    "'--lock' must be a positive whole number of minutes: '1.5'." \
    start \
    -l \
    1.5 \
    focus

check_rejected \
    lock_word \
    "'--lock' must be a positive whole number of minutes: 'ten'." \
    start \
    -l \
    ten \
    focus

check_rejected \
    password_space \
    "error(ctb_helper.sh::validate_args): '--password' must not contain" \
    start \
    -p \
    "s3cret word" \
    focus

check_rejected \
    password_double_quote \
    "'--password' must not contain spaces or quotes." \
    start \
    -p \
    's3cret"' \
    focus

check_rejected \
    password_single_quote \
    "'--password' must not contain spaces or quotes." \
    start \
    -p \
    "s3cret'" \
    focus

print_section "option applicability"
check_rejected \
    stop_with_lock \
    "error(ctb_helper.sh::validate_args): '--lock' applies only to 'start'." \
    stop \
    -l \
    5 \
    focus

check_rejected \
    stop_with_until \
    "'--until' applies only to 'start'." \
    stop \
    -u \
    5:00 \
    focus

check_rejected \
    list_with_password \
    "'--password' applies only to 'start'." \
    list \
    -p \
    secret

print_section "names"
check_rejected \
    start_without_names \
    "'start' requires at least one preset or block name." \
    start

check_rejected \
    stop_without_names \
    "'stop' requires at least one preset or block name." \
    stop

check_rejected \
    start_blank_name \
    "preset and block names must not be empty." \
    start \
    "   "

check_rejected \
    list_with_name \
    "'list' takes no names: 'extra'." \
    list \
    extra

check_rejected \
    edit_with_name \
    "'edit' takes no names: 'extra'." \
    edit \
    extra

finish
