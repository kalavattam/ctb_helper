#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Script: ctb_helper.sh
#
# Copyright 2026 by Kris Alavattam
# Email: kalavattam@gmail.com
#
# Anthropic Claude Code (Opus 5.5) was used in design, development, and
# documentation, with all output reviewed, edited, and approved by the author.
#
# Distributed under the MIT license.


# Require Bash >= 3.2 before doing any work. The Bash 3.2 floor is a deliberate
# exception to the shell standard; see 'docs/standards.md'. The first test uses
# POSIX '[' so that a non-Bash shell such as dash reaches the message.
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

# Set the presets file, which 'CTB_PRESETS' may override.
readonly PRESETS_FILE="${CTB_PRESETS:-${HOME}/.ctb_presets}"

# Set the pause between Cold Turkey calls in seconds, which 'CTB_DELAY' may
# override, and Cold Turkey's settings database, which 'CTB_DB' may override.
readonly DELAY_SEC="${CTB_DELAY:-2}"
readonly DB_FILE_MAC="/Library/Application Support/Cold Turkey/data-app.db"
readonly DB_FILE="${CTB_DB:-${DB_FILE_MAC}}"


function help_ctb() {
    cat >&2 << EOM
Usage
-----
  ctb_helper.sh
    start
    [--help]
    [--lock <int> | --until <time> | --password <str>]
    <name> [<name> ...]

  ctb_helper.sh
    stop
    [--help]
    <name> [<name> ...]

  ctb_helper.sh
    list

  ctb_helper.sh
    edit

  Start or stop groups of Cold Turkey Blocker blocks by preset or block name.

Parameters
----------
  1  command : str
    Subcommand to run:
      - 'start' starts blocks,
      - 'stop' stops them,
      - 'list' prints the presets, and
      - 'edit' opens the presets file in the editor named by 'VISUAL' or 'EDITOR' (default: 'nano').

  -h, --help : flag
    Print this help message and exit.

  -l, --lock : int
    Lock each started block for this many minutes. Applies only to 'start'.

  -u, --until : str
    Lock each started block until this clock time, given as 24-hour 'HH:MM' or 12-hour 'H:MMam' or 'H:MMpm'. A time that has already passed today means that time tomorrow. Applies only to 'start'.

  -p, --password : str
    Lock each started block with this password, which must not contain spaces or quotes. Applies only to 'start'.

  2  name : str
    One or more preset or block names. A name that matches a preset expands to that preset's blocks; any other name is passed to Cold Turkey as a block name. A block named more than once is started or stopped once.

Notes
-----
  Runtime requirements:
    - bash >= 3.2
    - Cold Turkey Blocker; locking with '--lock', '--until', or '--password' requires Cold Turkey Pro
    - sqlite3 and perl, to confirm that blocks started or stopped; both ship with macOS

  - Presets are read from '${PRESETS_FILE}', one per line, in the form 'name = Block One, Block Two'.
    + Lines that begin with '#' are comments.
    + Running 'start', 'list', or 'edit' creates an example file when none exists.
  - Block names must match the names in Cold Turkey exactly, including case.
  - Set 'CTB_PRESETS' to use another presets file, and set 'CTB_BIN' to the Cold Turkey executable when it is not in a default install location.
  - Specify at most one of '--lock', '--until', and '--password'.
  - A locked block cannot be stopped early.
  - Cold Turkey ends a lock at the start of a clock minute, so a lock of N minutes lasts between N - 1 and N minutes, and a lock of 1 minute can end at once.
  - Cold Turkey can drop a command that arrives too soon after another, so 'start' and 'stop' wait 'CTB_DELAY' seconds (default: 2) between Cold Turkey calls.
  - After the calls, 'start' and 'stop' read Cold Turkey's settings to confirm that each block turned on or off, and report each block that did not.
    + Set 'CTB_DB' when the settings database is not at '${DB_FILE_MAC}'.
    + When the settings cannot be read, the blocks are reported as started or stopped with a note that they were not confirmed.
  - A password given with '--password' is visible in shell history and the process list.
  - On a terminal, 'start' and 'stop' show their progress with a spinner on stderr, then how long they took.
  - On macOS, 'start' shows a desktop notification that lists the blocks that started.

Examples
--------
  1. Start every block in the 'focus' preset and lock it for 90 minutes.
    '''bash
    ctb_helper.sh start --lock 90 focus
    '''

  2. Start the 'focus' and 'deep' presets and lock them until 5:30 pm.
    '''bash
    ctb_helper.sh start --until 5:30pm focus deep
    '''

  3. Start two blocks by name without a lock.
    '''bash
    ctb_helper.sh start 'Social Media' News
    '''

  4. Stop the blocks in the 'focus' preset.
    '''bash
    ctb_helper.sh stop focus
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


# Write an error message to stderr for function 'func'.
function echo_err_func() {
    local func="${1}"

    shift 1
    echo "error($(print_context_diag 2 "${func}")):" \
        "$*" >&2
}


# Write a note to stderr in the caller's context: information that needs no
# action.
function echo_note() {
    echo "note($(print_context_diag 2)):" \
        "$*" >&2
}


# Print a string with leading and trailing whitespace removed.
function trim_space() {
    local str="${1}"

    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s\n' "${str}"
}


# Check, on behalf of the calling parser, that option 'opt' received a nonempty
# value 'val'.
function require_optarg() {
    local opt="${1}"
    local val="${2}"

    if [[ -z "${val}" ]]; then
        echo_err_func "${FUNCNAME[1]}" \
            "option '${opt}' requires a value."
        return 1
    fi
}


# Set argument defaults and declare the global arrays.
function init_globals() {
    cmd=""
    lock_min=""
    time_until=""
    password=""
    show_help=false

    # 'arr_preset_nam' and 'arr_preset_csv' are parallel indexed arrays,
    # because Bash 3.2 has no associative arrays.
    arr_nam=()
    arr_block=()
    arr_preset_nam=()
    arr_preset_csv=()

    # 'confirm_blocks' sorts the blocks in 'arr_sent' into 'arr_ok',
    # 'arr_miss', and 'arr_unknown'.
    arr_sent=()
    arr_ok=()
    arr_miss=()
    arr_unknown=()
}


# Print the index of preset 'nam' in 'arr_preset_nam', or return 1 when no
# preset has that name.
function find_preset_idx() {
    local nam="${1}"
    local idx

    for (( idx = 0; idx < ${#arr_preset_nam[@]}; idx++ )); do
        if [[ "${arr_preset_nam[idx]}" == "${nam}" ]]; then
            echo "${idx}"
            return 0
        fi
    done

    return 1
}


# Return 0 when block 'block' is already in 'arr_block'.
function has_block() {
    local block="${1}"
    local idx

    for (( idx = 0; idx < ${#arr_block[@]}; idx++ )); do
        if [[ "${arr_block[idx]}" == "${block}" ]]; then
            return 0
        fi
    done

    return 1
}


# Parse the options and names that follow the subcommand.
function parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
            -h|--help)
                show_help=true
                shift 1
                ;;

            -l|--lock)
                require_optarg "${1}" "${2:-}" || {
                    echo >&2
                    help_ctb
                    return 1
                }
                lock_min="${2}"
                shift 2
                ;;

            -u|--until)
                require_optarg "${1}" "${2:-}" || {
                    echo >&2
                    help_ctb
                    return 1
                }
                time_until="${2}"
                shift 2
                ;;

            -p|--password)
                require_optarg "${1}" "${2:-}" || {
                    echo >&2
                    help_ctb
                    return 1
                }
                password="${2}"
                shift 2
                ;;

            -*)
                echo_err "unknown option/parameter passed: '${1}'."
                echo >&2
                help_ctb
                return 1
                ;;

            *)
                arr_nam+=( "${1}" )
                shift 1
                ;;
        esac
    done
}


# Check the subcommand and the options and names it received.
function validate_args() {
    local nam
    local -a arr_opt_lock=()

    if [[ ! "${cmd}" =~ ^(start|stop|list|edit)$ ]]; then
        echo_err "unknown command: '${cmd}'."
        echo >&2
        help_ctb
        return 1
    fi

    if [[ -n "${lock_min}" ]]; then
        arr_opt_lock+=( "'--lock'" )
    fi

    if [[ -n "${time_until}" ]]; then
        arr_opt_lock+=( "'--until'" )
    fi

    if [[ -n "${password}" ]]; then
        arr_opt_lock+=( "'--password'" )
    fi

    if [[ "${cmd}" != "start" && "${#arr_opt_lock[@]}" -gt 0 ]]; then
        echo_err "${arr_opt_lock[0]} applies only to 'start'."
        return 1
    fi

    if [[ "${#arr_opt_lock[@]}" -gt 1 ]]; then
        echo_err \
            "specify at most one of '--lock', '--until', and" \
            "'--password'."
        return 1
    fi

    if [[ -n "${lock_min}" && ! "${lock_min}" =~ ^[1-9][0-9]*$ ]]; then
        echo_err \
            "'--lock' must be a positive whole number of minutes:" \
            "'${lock_min}'."
        return 1
    fi

    # Cold Turkey rejects a password that contains spaces or quotes.
    case "${password}" in
        *[[:space:]\"\']*)
            echo_err "'--password' must not contain spaces or quotes."
            return 1
            ;;
    esac

    if [[ "${cmd}" == "list" || "${cmd}" == "edit" ]]; then
        if [[ "${#arr_nam[@]}" -gt 0 ]]; then
            echo_err "'${cmd}' takes no names: '${arr_nam[0]}'."
            return 1
        fi
        return 0
    fi

    if [[ ! "${DELAY_SEC}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo_err \
            "'CTB_DELAY' must be a number of seconds, such as '2' or '0.5':" \
            "'${DELAY_SEC}'."
        return 1
    fi

    if [[ "${#arr_nam[@]}" -eq 0 ]]; then
        echo_err "'${cmd}' requires at least one preset or block name."
        return 1
    fi

    for nam in "${arr_nam[@]}"; do
        if [[ -z "$(trim_space "${nam}")" ]]; then
            echo_err "preset and block names must not be empty."
            return 1
        fi
    done
}


# Create an example presets file when none exists.
function ensure_presets() {
    if [[ -f "${PRESETS_FILE}" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "${PRESETS_FILE}")"
    cat > "${PRESETS_FILE}" << EOM
# ctb presets: name = Block One, Block Two, ...
# Block names must match Cold Turkey exactly.
focus = Social Media, News
EOM
    echo_note "created an example presets file: '${PRESETS_FILE}'."
}


# Read the presets file into 'arr_preset_nam', the preset names in file order,
# and 'arr_preset_csv', which maps each name to its comma-separated block
# names. A name that appears on more than one line combines their blocks.
function read_presets() {
    local line
    local nam
    local csv_block
    local idx

    if [[ ! -f "${PRESETS_FILE}" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="$(trim_space "${line}")"
        if [[ -z "${line}" || "${line}" == \#* || "${line}" != *=* ]]; then
            continue
        fi

        nam="$(trim_space "${line%%=*}")"
        csv_block="$(trim_space "${line#*=}")"
        if [[ -z "${nam}" ]]; then
            continue
        fi

        if \
            idx="$(find_preset_idx "${nam}")"
        then
            arr_preset_csv[idx]="${arr_preset_csv[idx]},${csv_block}"
        else
            arr_preset_nam+=( "${nam}" )
            arr_preset_csv+=( "${csv_block}" )
        fi
    done < "${PRESETS_FILE}"
}


# Append each block in comma-separated list 'csv_block' to 'arr_block',
# trimming whitespace and skipping empty and repeated names.
function add_blocks() {
    local csv_block="${1}"
    local block
    local -a arr_csv_block=()

    IFS=',' read -r -a arr_csv_block <<< "${csv_block}"

    # Expand 'arr_csv_block' only when set, because an empty array is unbound
    # under 'set -u' before Bash 4.4.
    for block in ${arr_csv_block[@]+"${arr_csv_block[@]}"}; do
        block="$(trim_space "${block}")"
        if [[ -z "${block}" ]]; then
            continue
        fi

        if \
            has_block "${block}"
        then
            continue
        fi

        arr_block+=( "${block}" )
    done
}


# Resolve preset and block names into 'arr_block', keeping the first occurrence
# of each block. A name that is not a preset is one literal block name, even
# when it contains a comma.
function resolve_blocks() {
    local nam
    local idx

    for nam in "$@"; do
        nam="$(trim_space "${nam}")"

        if \
            idx="$(find_preset_idx "${nam}")"
        then
            add_blocks "${arr_preset_csv[idx]}"
        else
            if \
                ! has_block "${nam}"
            then
                arr_block+=( "${nam}" )
            fi
        fi
    done

    if [[ "${#arr_block[@]}" -eq 0 ]]; then
        echo_err "no block names resolved from: '$*'."
        return 1
    fi
}


# Print the whole minutes from now until clock time 'time_in', given as 24-hour
# 'HH:MM' or 12-hour 'H:MMam' or 'H:MMpm'. A time that has already passed today
# means that time tomorrow.
function calculate_minutes_until() {
    local time_in
    local meridiem=""
    local hour
    local minute
    local hour_min=0
    local hour_max=23
    local clock
    local now_hour
    local now_minute
    local diff

    time_in="$(printf '%s\n' "${1}" | tr '[:upper:]' '[:lower:]')"

    if [[ "${time_in}" == *[ap]m ]]; then
        meridiem="${time_in: -2}"
        time_in="${time_in%[ap]m}"
        hour_min=1
        hour_max=12
    fi

    if [[ ! "${time_in}" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        echo_err \
            "invalid time: '${1}'. Use 'HH:MM', such as '17:30', or" \
            "'H:MMam' or 'H:MMpm', such as '5:30pm'."
        return 1
    fi

    hour=$(( 10#${BASH_REMATCH[1]} ))
    minute=$(( 10#${BASH_REMATCH[2]} ))

    if (( hour < hour_min || hour > hour_max || minute > 59 )); then
        echo_err "invalid time: '${1}'."
        return 1
    fi

    if [[ "${meridiem}" == "pm" ]] && (( hour < 12 )); then
        hour=$(( hour + 12 ))
    elif [[ "${meridiem}" == "am" ]] && (( hour == 12 )); then
        hour=0
    fi

    # Read the hour and minute from one clock reading so that they agree.
    if \
        ! clock="$(date '+%H %M')"
    then
        echo_err "failed to read the current time with 'date'."
        return 1
    fi

    if [[ ! "${clock}" =~ ^[0-9]{2}\ [0-9]{2}$ ]]; then
        echo_err "unexpected output from 'date': '${clock}'."
        return 1
    fi

    read -r now_hour now_minute <<< "${clock}"

    diff=$(( hour * 60 + minute - 10#${now_hour} * 60 - 10#${now_minute} ))
    if (( diff <= 0 )); then
        diff=$(( diff + 1440 ))
    fi

    echo "${diff}"
}


# Convert '--until' to whole minutes in 'lock_min'.
function resolve_lock() {
    if [[ -z "${time_until}" ]]; then
        return 0
    fi

    if \
        ! lock_min="$(calculate_minutes_until "${time_until}")"
    then
        return 1
    fi
}


# Print the path to the Cold Turkey Blocker executable.
function find_ct_bin() {
    local dir_mac="/Applications/Cold Turkey Blocker.app/Contents/MacOS"
    local dir_win="Program Files/Cold Turkey"
    local fil_bin
    local -a arr_fil_bin=(
        "${dir_mac}/Cold Turkey Blocker"
        "/c/${dir_win}/Cold Turkey Blocker.exe"  # Git Bash
        "/mnt/c/${dir_win}/Cold Turkey Blocker.exe"  # WSL
    )

    if [[ -n "${CTB_BIN:-}" ]]; then
        if [[ ! -x "${CTB_BIN}" ]]; then
            echo_err "'CTB_BIN' is not an executable file: '${CTB_BIN}'."
            return 1
        fi

        printf '%s\n' "${CTB_BIN}"
        return 0
    fi

    for fil_bin in "${arr_fil_bin[@]}"; do
        if [[ -x "${fil_bin}" ]]; then
            printf '%s\n' "${fil_bin}"
            return 0
        fi
    done

    echo_err \
        "Cold Turkey Blocker not found in a default install location;" \
        "set 'CTB_BIN' to its executable."
    return 1
}


# Show a desktop notification on macOS; do nothing on other platforms.
function notify_desktop() {
    local title="${1}"
    local message="${2}"
    local script

    if \
        ! command -v osascript > /dev/null 2>&1
    then
        return 0
    fi

    # Escape backslashes and double quotes for an AppleScript string.
    title="${title//\\/\\\\}"
    title="${title//\"/\\\"}"
    message="${message//\\/\\\\}"
    message="${message//\"/\\\"}"

    script="display notification \"${message}\" with title \"${title}\""
    osascript -e "${script}" > /dev/null 2>&1 || true
}


# On a terminal, replace the status line on stderr with 'msg'.
function show_status() {
    local msg="${1}"

    if [[ -t 2 ]]; then
        printf '\r\033[K%s' "${msg}" >&2
    fi
}


# On a terminal, erase the status line on stderr.
function clear_status() {
    if [[ -t 2 ]]; then
        printf '\r\033[K' >&2
    fi
}


# Wait 'DELAY_SEC' seconds before the next Cold Turkey call or settings read.
# On a terminal, spin beside status message 'msg' on stderr while waiting.
function pause_ct() {
    local msg="${1}"
    local frames="|/-\\"
    local pid
    local idx=0

    if [[ "${DELAY_SEC}" =~ ^0+([.]0+)?$ ]]; then
        return 0
    fi

    if [[ ! -t 2 ]]; then
        sleep "${DELAY_SEC}"
        return 0
    fi

    sleep "${DELAY_SEC}" &
    pid=$!
    while kill -0 "${pid}" 2> /dev/null; do
        show_status "${frames:idx%4:1} ${msg}"
        idx=$(( idx + 1 ))
        sleep 0.1
    done
    wait "${pid}"
}


# On a terminal, print on stderr how long the command took since 'sec_start',
# an earlier value of 'SECONDS'.
function report_elapsed() {
    local sec_start="${1}"
    local sec=$(( SECONDS - sec_start ))

    if [[ ! -t 2 ]]; then
        return 0
    fi

    if (( sec >= 60 )); then
        printf 'Took %d min %d s.\n' $(( sec / 60 )) $(( sec % 60 )) >&2
    else
        printf 'Took %d s.\n' "${sec}" >&2
    fi
}


# Print 'verb' and the number of blocks that follow 'desc', then 'desc' when it
# is set, and then each block on its own indented line. Print nothing when no
# blocks follow.
function print_summary() {
    local verb="${1}"
    local desc="${2}"
    local noun="blocks"
    local block

    shift 2
    if [[ "$#" -eq 0 ]]; then
        return 0
    fi

    if [[ "$#" -eq 1 ]]; then
        noun="block"
    fi

    echo "${verb} $# ${noun}${desc:+, ${desc}}:"
    for block in "$@"; do
        echo "  ${block}"
    done
}


# Print Cold Turkey's state for each block, one block per line: 'on' or 'off',
# a tab, and the block name. Cold Turkey keeps its settings in database
# 'DB_FILE' as 'CTB17' and the hexadecimal digits of JSON whose bytes are each
# shifted up by 17. Return 1 when the settings cannot be read.
function read_block_states() {
    local -r query="SELECT value FROM settings WHERE key = 'settings';"

    # The Perl program avoids single quotes so that it can sit inside one.
    # shellcheck disable=SC2016
    local -r decode='
        my $val = do { local $/; <STDIN> };
        defined $val or exit 1;
        $val =~ s/\s+\z//;
        $val =~ s/\ACTB17// or exit 1;
        $val =~ /\A(?:[0-9A-Fa-f]{2})+\z/ or exit 1;
        my $raw = join q(), map { chr((ord($_) - 17) % 256) }
            split //, pack(q(H*), $val);
        my $set = eval { JSON::PP->new->utf8->decode($raw) };
        ref $set eq q(HASH) && ref $set->{blocks} eq q(HASH) or exit 1;
        binmode STDOUT, q(:encoding(UTF-8));
        for my $nam (sort keys %{ $set->{blocks} }) {
            my $on = $set->{blocks}{$nam}{enabled};
            $on = ref $on ? $on : (defined $on && $on eq q(true));
            print $on ? q(on) : q(off), "\t", $nam, "\n";
        }
    '

    if [[ ! -r "${DB_FILE}" ]]; then
        return 1
    fi

    if \
        ! command -v sqlite3 > /dev/null 2>&1 \
            || ! command -v perl > /dev/null 2>&1
    then
        return 1
    fi

    # Open the database read-only so that reading it can never change Cold
    # Turkey's settings.
    sqlite3 -readonly "${DB_FILE}" "${query}" 2> /dev/null \
        | perl -MJSON::PP -e "${decode}" 2> /dev/null
}


# Sort the blocks in 'arr_sent' by whether Cold Turkey shows them in state
# 'want', 'on' or 'off': into 'arr_ok' when they are, 'arr_miss' when they are
# in the other state, and 'arr_unknown' when Cold Turkey has no such block.
# Read the settings up to three times, 'DELAY_SEC' apart, while any block is in
# the other state. Return 1 when the settings cannot be read.
function confirm_blocks() {
    local want="${1}"
    local nl=$'\n'
    local tab=$'\t'
    local states
    local block
    local try

    for (( try = 1; try <= 3; try++ )); do
        pause_ct "Checking Cold Turkey's settings"

        if \
            ! states="$(read_block_states)"
        then
            clear_status
            return 1
        fi

        arr_ok=()
        arr_miss=()
        arr_unknown=()
        for block in "${arr_sent[@]}"; do
            case "${nl}${states}${nl}" in
                *"${nl}${want}${tab}${block}${nl}"*)
                    arr_ok+=( "${block}" )
                    ;;

                *"${tab}${block}${nl}"*)
                    arr_miss+=( "${block}" )
                    ;;

                *)
                    arr_unknown+=( "${block}" )
                    ;;
            esac
        done

        if [[ "${#arr_miss[@]}" -eq 0 ]]; then
            clear_status
            return 0
        fi
    done

    clear_status
}


# Report, on behalf of the calling function, each block in 'arr_unknown' as
# missing from Cold Turkey and each block in 'arr_miss' with message 'msg'.
function report_unconfirmed() {
    local msg="${1}"
    local block

    for block in ${arr_unknown[@]+"${arr_unknown[@]}"}; do
        echo_err_func "${FUNCNAME[1]}" \
            "Cold Turkey has no block named '${block}'."
    done

    for block in ${arr_miss[@]+"${arr_miss[@]}"}; do
        echo_err_func "${FUNCNAME[1]}" \
            "block '${block}' ${msg}."
    done
}


# Start each block in 'arr_block' with the lock that 'lock_min' or 'password'
# selects, waiting 'DELAY_SEC' seconds between Cold Turkey calls. Then confirm
# in Cold Turkey's settings that each block is on, print a summary, and notify
# which blocks started.
function start_blocks() {
    local fil_bin
    local block
    local idx
    local desc=""
    local desc_lock=""
    local message
    local n_fail=0
    local sec_start="${SECONDS}"
    local -a arr_opt_lock=()
    local -a arr_started=()

    if [[ -n "${lock_min}" ]]; then
        arr_opt_lock=( -lock "${lock_min}" )
        desc="locked for ${lock_min} min"
        desc_lock=" (locked ${lock_min} min)"
        if [[ -n "${time_until}" ]]; then
            desc="locked until ${time_until}"
        fi
    elif [[ -n "${password}" ]]; then
        arr_opt_lock=( -password "${password}" )
        desc="password-locked"
        desc_lock=" (password-locked)"
    fi

    if \
        ! fil_bin="$(find_ct_bin)"
    then
        return 1
    fi

    for (( idx = 0; idx < ${#arr_block[@]}; idx++ )); do
        block="${arr_block[idx]}"
        if (( idx > 0 )); then
            pause_ct "Starting blocks: ${idx} of ${#arr_block[@]} sent"
        fi

        # Discard Cold Turkey's output, which is only blank lines; the settings
        # show whether the block started.
        show_status "| Starting blocks: ${idx} of ${#arr_block[@]} sent"
        if \
            "${fil_bin}" -start "${block}" \
                ${arr_opt_lock[@]+"${arr_opt_lock[@]}"} > /dev/null 2>&1
        then
            arr_sent+=( "${block}" )
        else
            clear_status
            echo_err "Cold Turkey failed to start block '${block}'."
            n_fail=$(( n_fail + 1 ))
        fi
    done
    clear_status

    if [[ "${#arr_sent[@]}" -gt 0 ]]; then
        if \
            confirm_blocks on
        then
            arr_started=( ${arr_ok[@]+"${arr_ok[@]}"} )
            report_unconfirmed "did not start; run 'start' again for it"
            n_fail=$(( n_fail + ${#arr_miss[@]} + ${#arr_unknown[@]} ))
        else
            echo_note \
                "could not read Cold Turkey's settings to confirm that the" \
                "blocks started."
            arr_started=( "${arr_sent[@]}" )
        fi
    fi

    print_summary "Started" "${desc}" ${arr_started[@]+"${arr_started[@]}"}

    if [[ "${#arr_started[@]}" -gt 0 ]]; then
        printf -v message '%s, ' "${arr_started[@]}"
        notify_desktop "Cold Turkey" "Started: ${message%, }${desc_lock}"
    fi

    report_elapsed "${sec_start}"

    if [[ "${n_fail}" -gt 0 ]]; then
        return 1
    fi
}


# Stop each block in 'arr_block', waiting 'DELAY_SEC' seconds between Cold
# Turkey calls. Then confirm in Cold Turkey's settings that each block is off,
# and print a summary.
function stop_blocks() {
    local fil_bin
    local block
    local idx
    local n_fail=0
    local sec_start="${SECONDS}"
    local -a arr_stopped=()

    if \
        ! fil_bin="$(find_ct_bin)"
    then
        return 1
    fi

    for (( idx = 0; idx < ${#arr_block[@]}; idx++ )); do
        block="${arr_block[idx]}"
        if (( idx > 0 )); then
            pause_ct "Stopping blocks: ${idx} of ${#arr_block[@]} sent"
        fi

        show_status "| Stopping blocks: ${idx} of ${#arr_block[@]} sent"
        if \
            "${fil_bin}" -stop "${block}" > /dev/null 2>&1
        then
            arr_sent+=( "${block}" )
        else
            clear_status
            echo_err \
                "Cold Turkey failed to stop block '${block}'; it may be" \
                "locked."
            n_fail=$(( n_fail + 1 ))
        fi
    done
    clear_status

    if [[ "${#arr_sent[@]}" -gt 0 ]]; then
        if \
            confirm_blocks off
        then
            arr_stopped=( ${arr_ok[@]+"${arr_ok[@]}"} )
            report_unconfirmed "is still on; it may be locked"
            n_fail=$(( n_fail + ${#arr_miss[@]} + ${#arr_unknown[@]} ))
        else
            echo_note \
                "could not read Cold Turkey's settings to confirm that the" \
                "blocks stopped."
            arr_stopped=( "${arr_sent[@]}" )
        fi
    fi

    print_summary "Stopped" "" ${arr_stopped[@]+"${arr_stopped[@]}"}
    report_elapsed "${sec_start}"

    if [[ "${n_fail}" -gt 0 ]]; then
        return 1
    fi
}


# Print each preset with the block names that 'start' would use for it.
function list_presets() {
    local idx
    local blocks

    if [[ "${#arr_preset_nam[@]}" -eq 0 ]]; then
        echo_note "no presets are defined in '${PRESETS_FILE}'."
        return 0
    fi

    for (( idx = 0; idx < ${#arr_preset_nam[@]}; idx++ )); do
        arr_block=()
        add_blocks "${arr_preset_csv[idx]}"

        blocks="(no blocks)"
        if [[ "${#arr_block[@]}" -gt 0 ]]; then
            printf -v blocks '%s, ' "${arr_block[@]}"
            blocks="${blocks%, }"
        fi

        printf '  %-12s %s\n' "${arr_preset_nam[idx]}" "${blocks}"
    done
}


# Open the presets file in the editor named by 'VISUAL' or 'EDITOR'.
function edit_presets() {
    local -a arr_editor

    # Split the editor command on whitespace so that a value with arguments,
    # such as 'subl -w', works.
    read -r -a arr_editor <<< "${VISUAL:-${EDITOR:-nano}}"
    if [[ "${#arr_editor[@]}" -eq 0 ]]; then
        echo_err "'VISUAL' or 'EDITOR' names no editor command."
        return 1
    fi

    "${arr_editor[@]}" "${PRESETS_FILE}"
}


function main() {
    init_globals

    if [[ -z "${1:-}" || "${1}" =~ ^(-h|--help|help)$ ]]; then
        help_ctb
        return 0
    fi

    cmd="${1}"
    shift 1

    parse_args "$@" || return 1

    if [[ "${show_help}" == "true" ]]; then
        help_ctb
        return 0
    fi

    validate_args || return 1

    if [[ "${cmd}" != "stop" ]]; then
        ensure_presets
    fi
    read_presets

    case "${cmd}" in
        start)
            resolve_lock                   || return 1
            resolve_blocks "${arr_nam[@]}" || return 1
            start_blocks                   || return 1
            ;;

        stop)
            resolve_blocks "${arr_nam[@]}" || return 1
            stop_blocks                    || return 1
            ;;

        list)
            list_presets
            ;;

        edit)
            edit_presets
            ;;
    esac
}


main "$@"
