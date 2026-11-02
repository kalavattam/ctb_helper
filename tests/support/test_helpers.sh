#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: test_helpers.sh
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
    echo "error(test_helpers.sh):" \
        "this test suite requires Bash >= 3.2." >&2
    exit 1
elif ((
    BASH_VERSINFO[0] < 3 || ( BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2 )
)); then
    echo "error(test_helpers.sh):" \
        "this test suite requires Bash >= 3.2; current version is" \
        "'${BASH_VERSION}'." >&2
    exit 1
fi


# Set paths used by test scripts.
# shellcheck disable=SC2034
{
    TEST_DIR_LIB="$(
        cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd
    )"
    TEST_DIR="$(cd "${TEST_DIR_LIB}/.." > /dev/null 2>&1 && pwd)"
    ROOT_REPO="$(cd "${TEST_DIR}/.." > /dev/null 2>&1 && pwd)"
    TEST_DIR_OUT="${TEST_ARTIFACT_ROOT:-${ROOT_REPO}/artifacts/tests}"

    if [[ "${TEST_DIR_OUT}" != /* || "${TEST_DIR_OUT}" == "/" ]]; then
        echo "error(test_helpers.sh):" \
            "TEST_ARTIFACT_ROOT must be an absolute non-root path." >&2
        exit 1
    fi

    TEST_OUT_PARENT="$(
        cd "$(dirname "${TEST_DIR_OUT}")" > /dev/null 2>&1 && pwd -P
    )" || {
        echo "error(test_helpers.sh):" \
            "TEST_ARTIFACT_ROOT parent does not exist." >&2
        exit 1
    }
    TEST_DIR_OUT="${TEST_OUT_PARENT}/$(basename "${TEST_DIR_OUT}")"
    ROOT_REPO_REAL="$(cd "${ROOT_REPO}" > /dev/null 2>&1 && pwd -P)"

    case "${TEST_DIR_OUT}/" in
        "${ROOT_REPO_REAL}/"*)
            if \
                [[ "${TEST_DIR_OUT}" != "${ROOT_REPO_REAL}/artifacts/tests" ]]
            then
                echo "error(test_helpers.sh):" \
                    "TEST_ARTIFACT_ROOT must be outside the repository." >&2
                exit 1
            fi
            ;;
    esac

    TEST_DIR_TMP="${TEST_DIR_OUT}/tmp"
    TEST_DIR_LOG="${TEST_DIR_OUT}/logs"

    # Run the script under test with the Bash running this test unless
    # 'TEST_BASH' names another.
    TEST_BASH="${TEST_BASH:-${BASH}}"
    CTB_HELPER="${ROOT_REPO}/bin/ctb_helper.sh"

    DIR_FIX="${TEST_DIR}/fixtures/ctb_helper"
    DIR_PRESETS="${DIR_FIX}/presets"
    DIR_TOOL="${DIR_FIX}/tool"
}

export TEST_ARTIFACT_ROOT="${TEST_DIR_OUT}"
export TEST_BASH
mkdir -p "${TEST_DIR_TMP}" "${TEST_DIR_LOG}"


# Initialize result counters.
TEST_PASS=0
TEST_FAIL=0
TEST_WARN=0
TEST_SKIP=0
TEST_NAME="${TEST_NAME:-$(basename "${0}")}"


# Print a test section heading.
function print_section() {
    printf '\n-- %s --\n' "${1:-${TEST_NAME}}"
}


# Record a passing assertion.
function record_pass() {
    TEST_PASS=$(( TEST_PASS + 1 ))
    printf 'PASS: %s\n' "$*"
}


# Record a failing assertion.
function record_fail() {
    TEST_FAIL=$(( TEST_FAIL + 1 ))
    printf 'FAIL: %s\n' "$*" >&2
}


# Record a non-fatal warning.
function record_warn() {
    TEST_WARN=$(( TEST_WARN + 1 ))
    printf 'WARN: %s\n' "$*" >&2
}


# Record a skipped check.
function record_skip() {
    TEST_SKIP=$(( TEST_SKIP + 1 ))
    printf 'SKIP: %s\n' "$*"
}


# Stop the test with a recorded failure when a precondition is unmet.
function fail_precondition() {
    record_fail "precondition: $*"
    finish || true
    exit 1
}


# Prepare the environment shared by every test: check the generated fixtures,
# create an empty per-test scratch directory, and put the stubs first on
# 'PATH'. 'CTB_BIN' always names the Cold Turkey stub, so no test can reach a
# real Cold Turkey install.
function setup_test_env() {
    local nam_test="${TEST_NAME//[^A-Za-z0-9_.-]/_}"

    if [[ ! -x "${DIR_TOOL}/cold_turkey" ]]; then
        fail_precondition \
            "fixtures are missing; run 'bash tests/run_tests.sh' or" \
            "'bash tests/fixtures/ctb_helper/make.sh'."
    fi

    TEST_DIR_CASE="${TEST_DIR_TMP}/${nam_test}"
    rm -rf "${TEST_DIR_CASE}"
    mkdir -p "${TEST_DIR_CASE}"

    PATH="${DIR_TOOL}:${PATH}"
    CTB_BIN="${DIR_TOOL}/cold_turkey"
    CTB_FAKE_LOG="${TEST_DIR_CASE}/cold_turkey.log"
    CTB_FAKE_OSA_LOG="${TEST_DIR_CASE}/osascript.log"
    CTB_FAKE_EDITOR_LOG="${TEST_DIR_CASE}/editor.log"
    CTB_PRESETS="${DIR_PRESETS}/basic.txt"
    export PATH CTB_BIN CTB_FAKE_LOG CTB_FAKE_OSA_LOG CTB_FAKE_EDITOR_LOG
    export CTB_PRESETS

    unset CTB_FAKE_FAIL CTB_FAKE_NOW VISUAL EDITOR
}


# Run 'ctb_helper.sh' with arguments as case 'nam', after clearing the stub
# logs. Write stdout to 'fil_out' and stderr to 'fil_err' under the per-test
# scratch directory, and set the exit status in 'ctb_status'.
function run_ctb() {
    local nam="${1}"

    shift 1
    fil_out="${TEST_DIR_CASE}/${nam}.out"
    fil_err="${TEST_DIR_CASE}/${nam}.err"

    : > "${CTB_FAKE_LOG}"
    : > "${CTB_FAKE_OSA_LOG}"
    : > "${CTB_FAKE_EDITOR_LOG}"

    if \
        "${TEST_BASH}" "${CTB_HELPER}" "$@" > "${fil_out}" 2> "${fil_err}"
    then
        ctb_status=0
    else
        ctb_status=$?
    fi
}


# Assert that the last 'run_ctb' call exited with status 'want'.
function assert_status() {
    local want="${1}"

    shift 1
    if [[ "${ctb_status}" == "${want}" ]]; then
        record_pass "$* (status ${want})"
    else
        record_fail \
            "$*: expected status ${want}, got ${ctb_status}; see" \
            "'${fil_err}'."
    fi
}


# Assert that file 'file' consists of exactly the given lines, each ended by a
# line feed. Pass no lines to assert an empty file.
function assert_lines() {
    local file="${1}"
    local lbl="${2}"
    local want=""
    local have

    shift 2
    if [[ "$#" -gt 0 ]]; then
        want="$(printf '%s\n' "$@"; printf 'x')"
        want="${want%x}"
    fi

    # Append a sentinel so that command substitution keeps trailing newlines.
    have="$(cat "${file}"; printf 'x')"
    have="${have%x}"

    if [[ "${have}" == "${want}" ]]; then
        record_pass "${lbl}"
    else
        record_fail "${lbl}; see '${file}'."
        printf -- '--- expected:\n%s--- actual:\n%s---\n' \
            "${want}" "${have}" >&2
    fi
}


# Assert that file 'file' contains the fixed string 'text'.
function assert_text_found() {
    local file="${1}"
    local text="${2}"
    local lbl="${3:-${2}}"

    if \
        grep -F -q -- "${text}" "${file}"
    then
        record_pass "${lbl}"
    else
        record_fail "${lbl}; '${text}' not found in '${file}'."
    fi
}


# Assert that file 'file' does not contain the fixed string 'text'.
function assert_text_absent() {
    local file="${1}"
    local text="${2}"
    local lbl="${3:-${2}}"

    if \
        grep -F -q -- "${text}" "${file}"
    then
        record_fail "${lbl}; '${text}' found in '${file}'."
    else
        record_pass "${lbl}"
    fi
}


# Print the final summary and return 1 when any failure was recorded.
function finish() {
    printf \
        '\nSummary for %s: pass=%d fail=%d warn=%d skip=%d\n' \
        "${TEST_NAME}" "${TEST_PASS}" "${TEST_FAIL}" "${TEST_WARN}" \
        "${TEST_SKIP}"

    if (( TEST_FAIL > 0 )); then
        return 1
    fi

    return 0
}
