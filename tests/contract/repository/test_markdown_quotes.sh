#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_markdown_quotes.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


set -euo pipefail

TEST_NAME="Markdown curly quotes"

# shellcheck source=tests/support/test_helpers.sh
source "$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null 2>&1 && pwd
)/support/test_helpers.sh"


# Run 'format_md_quotes.sh' with arguments as case 'nam'. Write stdout to
# 'fil_out' and stderr to 'fil_err' under the per-test scratch directory, and
# set the exit status in 'tool_status'.
function run_tool() {
    local nam="${1}"

    shift 1
    fil_out="${TEST_DIR_CASE}/${nam}.out"
    fil_err="${TEST_DIR_CASE}/${nam}.err"

    if \
        "${TEST_BASH}" "${tool}" "$@" > "${fil_out}" 2> "${fil_err}"
    then
        tool_status=0
    else
        tool_status=$?
    fi
}


# Assert that the last 'run_tool' call exited with status 'want'.
function assert_tool_status() {
    local want="${1}"

    shift 1
    if [[ "${tool_status}" == "${want}" ]]; then
        record_pass "$* (status ${want})"
    else
        record_fail \
            "$*: expected status ${want}, got ${tool_status}; see" \
            "'${fil_err}'."
    fi
}


# Assert that files 'fil_a' and 'fil_b' are byte-for-byte identical.
function assert_same_bytes() {
    local fil_a="${1}"
    local fil_b="${2}"
    local lbl="${3}"

    if \
        cmp -s "${fil_a}" "${fil_b}"
    then
        record_pass "${lbl}"
    else
        record_fail "${lbl}; '${fil_a}' and '${fil_b}' differ."
    fi
}


setup_test_env
tool="${ROOT_REPO}/dev/tools/format_md_quotes.sh"
dir_fix_quotes="${TEST_DIR}/fixtures/format_md_quotes"
fil_input="${dir_fix_quotes}/format/input.txt"
fil_expected="${dir_fix_quotes}/format/expected.txt"

if [[ ! -f "${fil_expected}" ]]; then
    fail_precondition \
        "the 'format/' fixtures are missing; run" \
        "'bash tests/fixtures/format_md_quotes/make.sh'."
fi

print_section "checking"
cksum_before="$(cksum < "${fil_input}")"
run_tool check_input "${fil_input}"
assert_tool_status 1 "check_input"

if [[ "$(cksum < "${fil_input}")" == "${cksum_before}" ]]; then
    record_pass "check_input: input file unchanged"
else
    record_fail "check_input: checking changed '${fil_input}'."
fi

n_found="$(grep -c ': straight .* in Markdown prose$' "${fil_out}" || true)"
if [[ "${n_found}" -eq 27 ]]; then
    record_pass "check_input: 27 straight quotes found"
else
    record_fail "check_input: expected 27 straight quotes, found ${n_found}."
fi

assert_text_found \
    "${fil_out}" \
    "${fil_input}:3:18: straight ' in Markdown prose" \
    "check_input: apostrophe reported by line and column"

assert_text_found \
    "${fil_out}" \
    "${fil_input}:8:58: straight \" in Markdown prose" \
    "check_input: column counts multibyte characters once"

assert_text_found \
    "${fil_out}" \
    "  -> Apostrophes: Kris’s repo, don’t, it’s." \
    "check_input: converted line previewed"

assert_text_absent \
    "${fil_out}" \
    "${fil_input}:5:" \
    "check_input: inline code spans skipped"

assert_text_absent \
    "${fil_out}" \
    "${fil_input}:13:" \
    "check_input: fenced code skipped"

assert_text_found \
    "${fil_err}" \
    "note(format_md_quotes.sh::main): found 27 straight quotes in 1 file;" \
    "check_input: summary note"

run_tool check_expected "${fil_expected}"
assert_tool_status 0 "check_expected"
assert_lines "${fil_out}" "check_expected: nothing reported"

print_section "converting"
fil_copy="${TEST_DIR_CASE}/converted.md"
cp "${fil_input}" "${fil_copy}"  # fixture-perturbation: rewritten in place.
run_tool write_copy --write "${fil_copy}"
assert_tool_status 0 "write_copy"
assert_same_bytes \
    "${fil_copy}" \
    "${fil_expected}" \
    "write_copy: conversion matches the expected output byte for byte"

assert_text_found \
    "${fil_out}" \
    "converted: ${fil_copy} (27 quotes)" \
    "write_copy: converted file reported"

cksum_before="$(cksum < "${fil_copy}")"
run_tool write_again --write "${fil_copy}"
assert_tool_status 0 "write_again"

if [[ "$(cksum < "${fil_copy}")" == "${cksum_before}" ]]; then
    record_pass "write_again: a second conversion changes nothing"
else
    record_fail "write_again: a second conversion changed '${fil_copy}'."
fi

print_section "arguments"
run_tool no_files
assert_tool_status 1 "no_files"
assert_text_found \
    "${fil_err}" \
    "error(format_md_quotes.sh::parse_args): give at least one Markdown" \
    "no_files: diagnostic"

run_tool unknown_option --bogus "${fil_expected}"
assert_tool_status 1 "unknown_option"
assert_text_found \
    "${fil_err}" \
    "unknown option/parameter passed: '--bogus'." \
    "unknown_option: exact token"

run_tool missing_file "${TEST_DIR_CASE}/missing.md"
assert_tool_status 1 "missing_file"
assert_text_found \
    "${fil_err}" \
    "error(format_md_quotes.sh::process_file): not a file:" \
    "missing_file: diagnostic"

print_section "repository Markdown"
arr_md=()
while IFS= read -r fil; do
    arr_md+=( "${fil}" )
done < <(
    find "${ROOT_REPO}" \
        \( -path "${ROOT_REPO}/.git" -o -path "${ROOT_REPO}/artifacts" \) \
        -prune -o -type f -name '*.md' -print \
        | LC_ALL=C sort
)

# Prove that the scan inspected files rather than passing vacuously.
if [[ "${#arr_md[@]}" -ge 5 ]]; then
    record_pass "found ${#arr_md[@]} Markdown files"
else
    record_fail "found ${#arr_md[@]} Markdown files; expected at least 5."
fi

run_tool repository ${arr_md[@]+"${arr_md[@]}"}
assert_tool_status 0 "repository: no straight quotes in Markdown prose"

if [[ "${tool_status}" -ne 0 ]]; then
    cat "${fil_out}" >&2
fi

finish
