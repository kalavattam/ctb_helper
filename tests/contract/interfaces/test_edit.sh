#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_edit.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="ctb_helper edit"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


setup_test_env

print_section "choosing the editor"
VISUAL="editor --wait"
EDITOR="unused_editor"
export VISUAL EDITOR
run_ctb visual_with_args edit
assert_status 0 "visual_with_args"
assert_lines \
    "${CTB_FAKE_EDITOR_LOG}" \
    "visual_with_args: 'VISUAL' split into a command and its arguments" \
    "[--wait][${CTB_PRESETS}]"

unset VISUAL
EDITOR="editor"
run_ctb editor_fallback edit
assert_status 0 "editor_fallback"
assert_lines \
    "${CTB_FAKE_EDITOR_LOG}" \
    "editor_fallback: 'EDITOR' used when 'VISUAL' is unset" \
    "[${CTB_PRESETS}]"

VISUAL="   "
export VISUAL
run_ctb visual_blank edit
assert_status 1 "visual_blank"
assert_text_found \
    "${fil_err}" \
    "error(ctb_helper.sh::edit_presets): 'VISUAL' or 'EDITOR' names no" \
    "visual_blank: diagnostic"

assert_lines "${CTB_FAKE_EDITOR_LOG}" "visual_blank: no editor call"

print_section "missing presets file"
VISUAL="editor"
CTB_PRESETS="${TEST_DIR_CASE}/new/presets"
run_ctb edit_without_file edit
assert_status 0 "edit_without_file"
assert_lines \
    "${CTB_FAKE_EDITOR_LOG}" \
    "edit_without_file: editor opens the new example file" \
    "[${CTB_PRESETS}]"

if [[ -s "${CTB_PRESETS}" ]]; then
    record_pass "edit_without_file: example presets file created"
else
    record_fail "edit_without_file: '${CTB_PRESETS}' was not created."
fi

finish
