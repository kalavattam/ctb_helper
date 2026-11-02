#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: format_md_quotes.sh
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
    echo "error(shell):" \
        "this script must be run under Bash >= 3.2." >&2
    exit 1
elif ((
    BASH_VERSINFO[0] < 3 || ( BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2 )
)); then
    echo "error($(basename "${BASH_SOURCE[0]}")):" \
        "this script requires Bash >= 3.2; current version is" \
        "'${BASH_VERSION}'." >&2
    exit 1
fi

# Run in safe mode, exiting on errors, unset variables, and pipe failures.
set -euo pipefail

# Work on bytes rather than characters so that results do not depend on the
# locale. In UTF-8, straight quotes are single bytes and never occur inside a
# multibyte character.
export LC_ALL=C

# Spell the curly quotes and dashes as their UTF-8 bytes so that this source
# stays ASCII.
readonly QUOTE_DOUBLE_OPEN=$'\xe2\x80\x9c'
readonly QUOTE_DOUBLE_CLOSE=$'\xe2\x80\x9d'
readonly QUOTE_SINGLE_OPEN=$'\xe2\x80\x98'
readonly QUOTE_SINGLE_CLOSE=$'\xe2\x80\x99'
readonly DASH_EN=$'\xe2\x80\x93'
readonly DASH_EM=$'\xe2\x80\x94'
readonly RE_FENCE_OPEN='^ {0,3}(`{3,}|~{3,})'
readonly RE_REFERENCE_DEF='^ {0,3}\[[^]]+\]:'


function help_format_md_quotes() {
    cat >&2 << EOM
Usage
-----
  format_md_quotes.sh
    [--help]
    [--write]
    <file> [<file> ...]

  Find straight quotes in Markdown prose and, with '--write', convert them to curly quotes.

Parameters
----------
  -h, --help : flag
    Print this help message and exit.

  -w, --write : flag
    Rewrite each file with curly quotes in place of the straight quotes found in its prose. Without this flag, report the straight quotes and the converted lines without changing any file.

  1  file : file
    One or more Markdown files to check or convert.

Notes
-----
  Runtime requirements:
    bash >= 3.2

  - A straight double quote becomes an opening or closing curly double quote, and a straight single quote becomes an opening curly single quote or a closing curly single quote, which also serves as the apostrophe.
  - A quote opens when it starts a line or follows whitespace, an opening bracket, a slash, a hyphen, an en or em dash, or an opening curly quote; otherwise it closes. Check the converted lines, because a leading apostrophe, as in "'90s", converts to an opening quote.
  - Fenced code blocks, inline code spans, HTML tags, link and image destinations with their titles, and reference-link definitions keep their straight quotes. So does a quote escaped with a backslash.
  - Without '--write', the exit status is 1 when any file has a straight quote in its prose.

Examples
--------
  1. Report the straight quotes in the repository's Markdown files.
    '''bash
    bash dev/tools/format_md_quotes.sh README.md docs/standards.md
    '''

  2. Convert them in place.
    '''bash
    bash dev/tools/format_md_quotes.sh --write README.md docs/standards.md
    '''
EOM
}


# Print diagnostic context as prescribed by 'SHELL.DIAGNOSTIC.FORM': the run
# script, then '::' and the function that called the 'echo_*' helper, or 'fun'
# when it is given. 'dep' is the index of that caller in 'FUNCNAME', which is 2
# when an 'echo_*' helper calls this function.
function print_context_diag() {
    local dep="${1}"
    local fun="${2:-}"
    local run="${0##*/}"
    local bot=$(( ${#FUNCNAME[@]} - 1 ))
    local ctx

    run="${run#-}"
    ctx="${run}"

    if [[ -z "${fun}" ]]; then
        fun="${FUNCNAME[dep]:-}"

        # The script's top level ('main' in the bottom frame) is not a
        # function.
        if [[ "${fun}" == "main" ]] && (( dep == bot )); then
            fun=""
        fi
    fi

    if [[ -n "${fun}" ]]; then
        ctx+="::${fun}"
    fi

    echo "${ctx}"
}


# Write an error message to stderr in the caller's context.
function echo_err() {
    echo "error($(print_context_diag 2)):" \
        "$*" >&2
}


# Write a note to stderr in the caller's context: information that needs no
# action.
function echo_note() {
    echo "note($(print_context_diag 2)):" \
        "$*" >&2
}


# Print 'noun' after count 'n', adding 's' unless 'n' is 1.
function print_count() {
    local n="${1}"
    local noun="${2}"

    if (( n == 1 )); then
        echo "${n} ${noun}"
    else
        echo "${n} ${noun}s"
    fi
}


# Set argument defaults and declare the global arrays.
function init_globals() {
    write=false
    n_quote=0
    n_file_quote=0
    arr_fil=()
    arr_col=()
    arr_quote=()
    line_out=""
}


# Parse the options and files.
function parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
            -h|--help)
                help_format_md_quotes
                exit 0
                ;;

            -w|--write)
                write=true
                shift 1
                ;;

            -*)
                echo_err "unknown option/parameter passed: '${1}'."
                echo >&2
                help_format_md_quotes
                return 1
                ;;

            *)
                arr_fil+=( "${1}" )
                shift 1
                ;;
        esac
    done

    if [[ "${#arr_fil[@]}" -eq 0 ]]; then
        echo_err "give at least one Markdown file."
        echo >&2
        help_format_md_quotes
        return 1
    fi
}


# Print the number of characters in string 'str', counting each UTF-8 multibyte
# character once.
function count_chars() {
    local str="${1}"

    str="${str//[$'\x80'-$'\xbf']/}"
    echo "${#str}"
}


# Return 0 when a quote that follows 'pre', the part of its line before it,
# opens a quotation.
function is_opening() {
    local pre="${1}"

    case "${pre}" in
        ""|*[[:space:]]|*[\(\[\{/-])
            return 0
            ;;

        *"${QUOTE_DOUBLE_OPEN}"|*"${QUOTE_SINGLE_OPEN}"|*"${DASH_EN}")
            return 0
            ;;

        *"${DASH_EM}")
            return 0
            ;;
    esac

    return 1
}


# Print the length of the code span that opens at byte 'idx' of 'line' with a
# run of 'n' backticks, or return 1 when no run of exactly 'n' backticks closes
# it on the same line.
function measure_code_span() {
    local line="${1}"
    local idx="${2}"
    local n="${3}"
    local len="${#line}"
    local j=$(( idx + n ))
    local run

    while (( j < len )); do
        if [[ "${line:j:1}" != '`' ]]; then
            j=$(( j + 1 ))
            continue
        fi

        run=0
        while [[ "${line:j:1}" == '`' ]]; do
            run=$(( run + 1 ))
            j=$(( j + 1 ))
        done

        if (( run == n )); then
            echo $(( j - idx ))
            return 0
        fi
    done

    return 1
}


# Print the length of the link destination that opens with '(' at byte 'idx' of
# 'line', through its matching ')', or return 1 when it does not close.
function measure_link_target() {
    local line="${1}"
    local idx="${2}"
    local len="${#line}"
    local j="${idx}"
    local depth=0
    local c

    while (( j < len )); do
        c="${line:j:1}"

        if [[ "${c}" == "\\" ]]; then
            j=$(( j + 2 ))
            continue
        fi

        if [[ "${c}" == "(" ]]; then
            depth=$(( depth + 1 ))
        elif [[ "${c}" == ")" ]]; then
            depth=$(( depth - 1 ))
            if (( depth == 0 )); then
                echo $(( j - idx + 1 ))
                return 0
            fi
        fi

        j=$(( j + 1 ))
    done

    return 1
}


# Convert the straight quotes in the prose of one line outside a fence. Set
# 'line_out' to the converted line, and set 'arr_col' and 'arr_quote' to the
# column and character of each straight quote converted.
function convert_line() {
    local line="${1}"
    local len="${#line}"
    local idx=0
    local c
    local n
    local span
    local tag
    local quote

    arr_col=()
    arr_quote=()
    line_out=""

    # A reference-link definition is a URL and title, not prose.
    if [[ "${line}" =~ ${RE_REFERENCE_DEF} ]]; then
        line_out="${line}"
        return 0
    fi

    while (( idx < len )); do
        c="${line:idx:1}"

        case "${c}" in
            "\\")
                # Keep an escaped character, such as '\"', as written.
                line_out+="${line:idx:2}"
                idx=$(( idx + 2 ))
                continue
                ;;

            '`')
                n=0
                while [[ "${line:idx+n:1}" == '`' ]]; do
                    n=$(( n + 1 ))
                done

                if \
                    span="$(measure_code_span "${line}" "${idx}" "${n}")"
                then
                    line_out+="${line:idx:span}"
                    idx=$(( idx + span ))
                else
                    line_out+="${line:idx:n}"
                    idx=$(( idx + n ))
                fi
                continue
                ;;

            '<')
                # Keep an HTML tag or autolink, attributes included.
                tag="${line:idx}"
                if \
                    [[ "${tag:1:1}" == [A-Za-z/!?] && "${tag}" == *'>'* ]]
                then
                    tag="${tag%%>*}>"
                    line_out+="${tag}"
                    idx=$(( idx + ${#tag} ))
                    continue
                fi
                ;;

            ']')
                # Keep a link or image destination and its title.
                if [[ "${line:idx+1:1}" == "(" ]]; then
                    if \
                        span="$(measure_link_target "${line}" $(( idx + 1 )))"
                    then
                        line_out+="${line:idx:span+1}"
                        idx=$(( idx + span + 1 ))
                        continue
                    fi
                fi
                ;;

            '"'|"'")
                if \
                    is_opening "${line:0:idx}"
                then
                    if [[ "${c}" == '"' ]]; then
                        quote="${QUOTE_DOUBLE_OPEN}"
                    else
                        quote="${QUOTE_SINGLE_OPEN}"
                    fi
                else
                    if [[ "${c}" == '"' ]]; then
                        quote="${QUOTE_DOUBLE_CLOSE}"
                    else
                        quote="${QUOTE_SINGLE_CLOSE}"
                    fi
                fi

                arr_col+=( $(( $(count_chars "${line:0:idx}") + 1 )) )
                arr_quote+=( "${c}" )
                line_out+="${quote}"
                idx=$(( idx + 1 ))
                continue
                ;;
        esac

        line_out+="${c}"
        idx=$(( idx + 1 ))
    done
}


# Return 0 when 'line' closes a fence opened by the run of backticks or tildes
# in 'fence': at most three spaces, a run of the same character at least as
# long, and nothing after it but whitespace.
function is_fence_close() {
    local line="${1}"
    local fence="${2}"
    local char="${fence:0:1}"
    local rest="${line#"${line%%[! ]*}"}"
    local run=0

    if (( ${#line} - ${#rest} > 3 )); then
        return 1
    fi

    while [[ "${rest:0:1}" == "${char}" ]]; do
        run=$(( run + 1 ))
        rest="${rest:1}"
    done

    (( run >= ${#fence} )) && [[ -z "${rest//[[:space:]]/}" ]]
}


# Check or convert one file. Print each straight quote in its prose as
# 'file:line:column', followed by the converted line, and rewrite the file when
# '--write' is given.
function process_file() {
    local fil="${1}"
    local line
    local eol
    local fence=""
    local n_line=0
    local n_found=0
    local k
    local text_out=""

    if [[ ! -f "${fil}" ]]; then
        echo_err "not a file: '${fil}'."
        return 1
    fi

    while :; do
        eol=$'\n'
        if \
            ! IFS= read -r line
        then
            if [[ -z "${line}" ]]; then
                break
            fi
            eol=""
        fi

        n_line=$(( n_line + 1 ))

        if [[ -n "${fence}" ]]; then
            line_out="${line}"
            if \
                is_fence_close "${line}" "${fence}"
            then
                fence=""
            fi
        elif [[ "${line}" =~ ${RE_FENCE_OPEN} ]]; then
            fence="${BASH_REMATCH[1]}"
            line_out="${line}"
        else
            convert_line "${line}"

            for (( k = 0; k < ${#arr_col[@]}; k++ )); do
                printf '%s:%d:%d: straight %s in Markdown prose\n' \
                    "${fil}" "${n_line}" "${arr_col[k]}" "${arr_quote[k]}"
            done

            if [[ "${#arr_col[@]}" -gt 0 ]]; then
                printf '  -> %s\n' "${line_out}"
                n_found=$(( n_found + ${#arr_col[@]} ))
            fi
        fi

        text_out+="${line_out}${eol}"
        if [[ -z "${eol}" ]]; then
            break
        fi
    done < "${fil}"

    if (( n_found == 0 )); then
        return 0
    fi

    n_quote=$(( n_quote + n_found ))
    n_file_quote=$(( n_file_quote + 1 ))

    if [[ "${write}" == "true" ]]; then
        printf '%s' "${text_out}" > "${fil}"
        echo "converted: ${fil} ($(print_count "${n_found}" quote))"
    fi
}


function main() {
    local fil
    local desc_quote
    local desc_file

    init_globals
    parse_args "$@" || return 1

    for fil in "${arr_fil[@]}"; do
        process_file "${fil}" || return 1
    done

    if (( n_quote == 0 )); then
        return 0
    fi

    desc_quote="$(print_count "${n_quote}" "straight quote")"
    desc_file="$(print_count "${n_file_quote}" file)"

    if [[ "${write}" == "true" ]]; then
        echo_note "converted ${desc_quote} in ${desc_file}."
        return 0
    fi

    echo_note \
        "found ${desc_quote} in ${desc_file}; run with '--write' to" \
        "convert them."
    return 1
}


main "$@"
