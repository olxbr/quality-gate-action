#!/bin/bash

## Colors
export ESC_SEQ='\033['
export C_END=$ESC_SEQ'0m'
export C_GRE=$ESC_SEQ'1;32m'
export C_YEL=$ESC_SEQ'1;33m'
export C_BLU=$ESC_SEQ'1;34m'
export C_RED=$ESC_SEQ'1;31m'
export C_WHT=$ESC_SEQ'1;37m'
export C_WHT_NO_BOLD=$ESC_SEQ'0;37m'

export E_GRE='\xE2\x9C\x85'
export E_YEL='\xE2\x9A\xA0'
export E_RED='\xE2\x9D\x97'
export E_TRO='\xF0\x9F\x8F\x86'
export E_SUM='\xF0\x9F\x85\xA2'
export E_MET='\xF0\x9F\x85\x9C'

function _log() {
    output=/dev/stdout

    case $1 in
    erro)
        logLevel="${C_RED}[ERRO]${C_END}"
        msg=${@/erro /};;
    warn)
        logLevel="${C_YEL}[WARN]${C_END}"
        msg=${@/warn /};;
    info)
        logLevel="${C_YEL}[INFO]${C_END}"
        msg=${@/info /};;
    debug)
        logLevel="${C_YEL}[DEBUG]${C_END}"
        msg=${@/debug/}
        [[ -n "$RUNNER_DEBUG" ]] &&
            output=/dev/stderr ||
            output=/dev/null;;
    *)  logLevel="${C_WHT}[INFO]${C_END}"; msg="$@";;
    esac

    echo -e "$(date +"%d-%b-%Y %H:%M:%S") ${logLevel} - ${msg}${C_END}" > $output
}

function _insert_warning_message() {
    local env_var=$1
    local warning_message=$2

    if [ -z "${!env_var}" ]; then
        eval "$env_var=\"$warning_message\""
    else
        eval "$env_var=\"${!env_var}<br>$warning_message\""
    fi
}

function _log_gates_to_skip_configuration() {
    _log warn "${C_YEL}Skipping Gates!${C_END}"
    _log warn "${C_YEL}$GATES_TO_SKIP${C_END}"
}

function _has_gate_to_skip() {
    local gate=$1
    if [[ $GATES_TO_SKIP == *$gate* ]]; then
        echo true
    else
        echo false
    fi
}

function _calc_max_retries_by_time_in_minutes() {
    local time_in_minutes=$1
    local initial_retry_delay=$2
    local max_retry_delay=$3
    local time_in_seconds=$((time_in_minutes * 60))
    local retries=0
    local multiplier=1

    while [ $time_in_seconds -gt 0 ]; do
        seconds_to_remove=$((initial_retry_delay * multiplier))

        if [ $seconds_to_remove -gt "$max_retry_delay" ]; then
            seconds_to_remove=$max_retry_delay
        fi

        time_in_seconds=$((time_in_seconds - seconds_to_remove))

        retries=$((retries + 1))
        multiplier=$((multiplier + 1))
    done

    echo $retries
}

function _retry_with_delay() {
    local retry_command="$1"
    local time_in_minutes="${2:-60}"

    local initial_retry_delay=3
    local max_retry_delay=60

    # Calculate max_retries based on time_in_minutes
    local max_retries=$(_calc_max_retries_by_time_in_minutes "$time_in_minutes" $initial_retry_delay $max_retry_delay)

    _log "${C_BLU}Running command [ $retry_command ] with retry (timeout: $time_in_minutes minute(s))...${C_END}"

    for ((i = 1; i <= max_retries; i++)); do
        if $retry_command; then
            _log "${C_BLU}Command succeeded${C_END}"
            break
        else
            _log "${C_BLU}Attempt $i failed${C_END}"

            if [ $i -lt $max_retries ]; then
                sleep_seconds=$((initial_retry_delay * i))
                if [ $sleep_seconds -gt $max_retry_delay ]; then
                    sleep_seconds=$max_retry_delay
                fi
                _log "${C_BLU}Retrying in $sleep_seconds seconds...${C_END}"
                sleep $sleep_seconds
            else
                _log warn "${C_YEL}Maximum number of retries reached. Exiting...${C_END}"
                break
            fi
        fi
    done
}
