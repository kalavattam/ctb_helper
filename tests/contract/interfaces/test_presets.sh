#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_presets.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper presets"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


setup_test_env

print_section "listing presets"
CTB_PRESETS="${DIR_PRESETS}/basic.txt"
run_ctb list_basic list
assert_status 0 "list_basic"
assert_lines \
    "${fil_out}" \
    "list_basic: presets in file order" \
    "  focus        Social Media, News" \
    "  deep         Social Media, News, Email"

CTB_PRESETS="${DIR_PRESETS}/messy.txt"
run_ctb list_messy list
assert_status 0 "list_messy"
assert_lines \
    "${fil_out}" \
    "list_messy: trimmed, merged, and deduplicated presets" \
    "  focus        Social Media, News, Shopping" \
    "  deep         Email, Slack" \
    "  empty        (no blocks)" \
    "  last         Final Block"

CTB_PRESETS="${DIR_PRESETS}/comments_only.txt"
run_ctb list_comments_only list
assert_status 0 "list_comments_only"
assert_lines "${fil_out}" "list_comments_only: no stdout"
assert_text_found \
    "${fil_err}" \
    "note(ctb_helper.sh::list_presets): no presets are defined in" \
    "list_comments_only: note on stderr"

print_section "resolving names"
CTB_PRESETS="${DIR_PRESETS}/messy.txt"
run_ctb start_merged start focus
assert_status 0 "start_merged"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_merged: blocks from both 'focus' lines, once each" \
    "[-start][Social Media]" \
    "[-start][News]" \
    "[-start][Shopping]"

run_ctb start_empty_preset start empty
assert_status 1 "start_empty_preset"
assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::resolve_blocks): no block names resolved from:" \
    "start_empty_preset: diagnostic"
assert_lines "${CTB_FAKE_LOG}" "start_empty_preset: no Cold Turkey call"

CTB_PRESETS="${DIR_PRESETS}/basic.txt"
run_ctb start_mixed start focus Reddit News deep
assert_status 0 "start_mixed"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_mixed: presets and block names in order, first occurrence only" \
    "[-start][Social Media]" \
    "[-start][News]" \
    "[-start][Reddit]" \
    "[-start][Email]"

run_ctb start_padded_name start "  focus  "
assert_status 0 "start_padded_name"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_padded_name: surrounding whitespace ignored" \
    "[-start][Social Media]" \
    "[-start][News]"

run_ctb start_comma_name start "a,b"
assert_status 0 "start_comma_name"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "start_comma_name: a literal name with a comma stays one block" \
    "[-start][a,b]"

print_section "missing presets file"
CTB_PRESETS="${TEST_DIR_CASE}/new/stop/presets"
run_ctb stop_without_file stop Reddit
assert_status 0 "stop_without_file"
assert_lines \
    "${CTB_FAKE_LOG}" \
    "stop_without_file: block stopped by name" \
    "[-stop][Reddit]"

if [[ -e "${CTB_PRESETS}" ]]; then
    record_fail "stop_without_file: 'stop' created '${CTB_PRESETS}'."
else
    record_pass "stop_without_file: no presets file created"
fi

CTB_PRESETS="${TEST_DIR_CASE}/new/list/presets"
run_ctb list_without_file list
assert_status 0 "list_without_file"
assert_text_found \
    "${fil_err}" \
    "note(ctb_helper.sh::ensure_presets): created an example presets file:" \
    "list_without_file: note on stderr"

assert_lines \
    "${CTB_PRESETS}" \
    "list_without_file: example presets file" \
    "# ctb presets: name = Block One, Block Two, ..." \
    "# Block names must match Cold Turkey exactly." \
    "focus = Social Media, News"

assert_lines \
    "${fil_out}" \
    "list_without_file: example preset listed" \
    "  focus        Social Media, News"

finish
