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
    case $1 in
    erro) logLevel="${C_RED}[ERRO]${C_END}" ;;
    warn) logLevel="${C_YEL}[WARN]${C_END}" ;;
    debug) [[ $ACTIONS_RUNNER_DEBUG == true ]] && logLevel="${C_YEL}[DEBUG]${C_END}" || return ;;
    *) logLevel="${C_WHT}[INFO]${C_END}" ;;
    esac

    msg=$( (($# == 2)) && echo "${2}" || echo "${1}")
    if (($# > 2)); then
        msg_evaluated=$(echo -e $msg) ## Transform hex to char
        msg_length=$(echo ${#msg_evaluated})
        msg_total_coll=$2
        msg_last_char=$3
        msg_space_end=$(printf '\\x20%.0s' $(seq 1 $(($msg_total_coll - $msg_length))))
        msg="${msg}${msg_space_end}${msg_last_char}"
    fi

    echo -e "$(date +"%d-%b-%Y %H:%M:%S") ${logLevel} - ${msg}${C_END}"
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

function _retry_with_delay() {
    local retry_command="$1"

    # 71 retries = 3630 seconds = 1 hour
    local max_retries=71
    local initial_retry_delay=3
    local max_retry_delay=60

    _log "${C_BLU}Running command [ $retry_command ] with retry...${C_END}"

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
