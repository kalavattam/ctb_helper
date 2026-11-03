#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: run_tests.sh
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
    echo "error(run_tests.sh):" \
        "this test runner requires Bash >= 3.2." >&2
    exit 1
elif ((
    BASH_VERSINFO[0] < 3 || ( BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2 )
)); then
    echo "error(run_tests.sh):" \
        "this test runner requires Bash >= 3.2; current version is" \
        "'${BASH_VERSION}'." >&2
    exit 1
fi

# Treat unset variables as errors. The runner omits '-e' and 'pipefail' so that
# it can run every test and aggregate their failures.
set -u


function die() {
    echo "error(run_tests.sh):" \
        "$@" >&2
    exit 1
}


function help_run_tests() {
    cat << EOM
Usage
-----
  run_tests.sh
    [--help] [--list]
    [<group> ...]

  Run the ctb_helper test suite.

Parameters
----------
  -h, --help : flag
    Print this help message and exit.

  --list : flag
    Print the deduplicated test selection without generating fixtures, creating artifacts, or running tests.

  1  group : str
    Test group to run: 'contract' runs the interface and repository contracts, and 'all-safe' runs every group. The default is 'all-safe'.

Notes
-----
  Runtime requirements:
    bash >= 3.2

  - Each test runs under the Bash running this script, or under the Bash named by 'TEST_BASH'.
  - Logs and scratch files go to 'artifacts/tests/' or to the absolute path outside the repository in 'TEST_ARTIFACT_ROOT'.

Examples
--------
  1. Run every test with the macOS system Bash.
    '''bash
    /bin/bash tests/run_tests.sh
    '''

  2. List the contract tests without running them.
    '''bash
    bash tests/run_tests.sh --list contract
    '''
EOM
}


function validate_group() {
    case "${1}" in
        contract|all-safe)
            return 0
            ;;

        *)
            die "unknown group: '${1}'."
            ;;
    esac
}


function add_group() {
    local fil

    case "${1}" in
        contract)
            while IFS= read -r fil; do
                arr_test+=( "${fil}" )
            done < <(
                find "${repo_root}/tests/contract" \
                    -type f -name 'test_*.sh' -print | LC_ALL=C sort
            )
            ;;

        all-safe)
            add_group contract
            ;;
    esac
}


# Return 0 when test 'fil' is already in 'arr_test_unique'.
function has_test() {
    local fil="${1}"
    local idx

    for (( idx = 0; idx < ${#arr_test_unique[@]}; idx++ )); do
        if [[ "${arr_test_unique[idx]}" == "${fil}" ]]; then
            return 0
        fi
    done

    return 1
}


# Generate the fixture set in 'tests/fixtures/<nam>/' with its 'make.sh' when
# its last-written output, 'sentinel', is missing.
function ensure_fixture() {
    local nam="${1}"
    local sentinel="${2}"
    local dir_fix="${repo_root}/tests/fixtures/${nam}"

    if [[ -f "${dir_fix}/${sentinel}" ]]; then
        return 0
    fi

    echo "note(run_tests.sh):" \
        "generating ${nam} fixtures."
    "${TEST_BASH}" "${dir_fix}/make.sh" \
        || die "fixture generation failed: '${nam}'."
}


repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null 2>&1 && pwd)"
list_only=0
arr_group=()
arr_test=()
arr_test_unique=()

while [[ "$#" -gt 0 ]]; do
    case "${1}" in
        -h|--help)
            help_run_tests
            exit 0
            ;;

        --list)
            list_only=1
            shift 1
            ;;

        -*)
            die "unknown option: '${1}'."
            ;;

        *)
            arr_group+=( "${1}" )
            shift 1
            ;;
    esac
done

if [[ "${#arr_group[@]}" -eq 0 ]]; then
    arr_group=( all-safe )
fi

# Validate every group before discovery, fixture generation, or test runs.
for group in "${arr_group[@]}"; do
    validate_group "${group}"
done

for group in "${arr_group[@]}"; do
    add_group "${group}"
done

for fil in ${arr_test[@]+"${arr_test[@]}"}; do
    if \
        ! has_test "${fil}"
    then
        arr_test_unique+=( "${fil}" )
    fi
done

if (( list_only == 1 )); then
    for fil in ${arr_test_unique[@]+"${arr_test_unique[@]}"}; do
        printf '%s\n' "${fil#"${repo_root}/"}"
    done
    exit 0
fi

if [[ "${#arr_test_unique[@]}" -eq 0 ]]; then
    die "the selected groups contain no tests."
fi

# Resolve the artifact root: 'artifacts/tests/' or an absolute path outside the
# repository.
artifact_root="${TEST_ARTIFACT_ROOT:-${repo_root}/artifacts/tests}"
if [[ "${artifact_root}" != /* || "${artifact_root}" == "/" ]]; then
    die "TEST_ARTIFACT_ROOT must be an absolute non-root path."
fi

mkdir -p "$(dirname "${artifact_root}")" \
    || die "cannot create the parent of '${artifact_root}'."
artifact_parent="$(
    cd "$(dirname "${artifact_root}")" > /dev/null 2>&1 && pwd -P
)" || die "TEST_ARTIFACT_ROOT parent does not exist."
artifact_root="${artifact_parent}/$(basename "${artifact_root}")"
repo_real="$(cd "${repo_root}" > /dev/null 2>&1 && pwd -P)"

case "${artifact_root}/" in
    "${repo_real}/"*)
        if [[ "${artifact_root}" != "${repo_real}/artifacts/tests" ]]; then
            die "TEST_ARTIFACT_ROOT must be outside the repository."
        fi
        ;;
esac

TEST_ARTIFACT_ROOT="${artifact_root}"
TEST_BASH="${TEST_BASH:-${BASH}}"
export TEST_ARTIFACT_ROOT TEST_BASH

log_root="${artifact_root}/logs"
mkdir -p "${log_root}" || die "cannot create '${log_root}'."

# Ask the Bash under test for its own version, so the single quotes are
# deliberate: the child shell, not this one, expands 'BASH_VERSION'.
# shellcheck disable=SC2016
bash_version="$("${TEST_BASH}" -c 'echo "${BASH_VERSION}"')"
echo "note(run_tests.sh):" \
    "testing with Bash '${bash_version}' at '${TEST_BASH}'."

# Generate each fixture set whose last-written output is missing.
ensure_fixture ctb_helper tool/sqlite3
ensure_fixture format_md_quotes format/expected.txt

passed=0
failed=0

for fil in "${arr_test_unique[@]}"; do
    rel="${fil#"${repo_root}/tests/"}"
    log="${log_root}/${rel%.sh}.log"

    mkdir -p "$(dirname "${log}")"
    echo "==== ${rel} ===="

    if \
        "${TEST_BASH}" "${fil}" > "${log}" 2>&1
    then
        passed=$(( passed + 1 ))
    else
        failed=$(( failed + 1 ))
    fi

    cat "${log}"
done

echo
printf 'Groups passed: %d\n' "${passed}"
printf 'Groups failed: %d\n' "${failed}"
(( failed == 0 ))
