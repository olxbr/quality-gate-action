#!/bin/bash

source "${ACTION_PATH}"/src/utils.sh

# Function to validate if Makefile exists
function _validate_makefile() {
    if [ -f "Makefile" ]; then
        echo true
    else
        echo false
    fi
}

# Function to validate if unit-test target exists
function _validate_makefile_target() {
    if grep -q "unit-test:" "Makefile"; then
        echo true
    else
        echo false
    fi
}

# Function to check if unit-test is passing
function _check_unit_test() {
    _log "${C_WHT}Checking Unit Test...${C_END}"
    is_unit_tests_pass=false

    unit_tests_warn_msg=""

    has_makefile=$(_validate_makefile)

    if [[ $has_makefile == true ]]; then
        has_makefile_target=$(_validate_makefile_target)

        if [[ $has_makefile_target == true ]]; then
            _log "${C_WHT}Running Unit Test...${C_END}"

            make unit-test && is_unit_tests_pass=true || true
            if [[ $is_unit_tests_pass == false ]]; then
                message="Unit Test Failed!"
                _log warn "${C_YEL}${message}${C_END}"
                _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
            fi
        else
            message="Unit-test target not found in Makefile!"
            _log warn "${C_YEL}${message}${C_END}"
            _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
        fi
    else
        message="Makefile not found!"
        _log warn "${C_YEL}${message}${C_END}"
        _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
    fi

    _log "${C_WHT}Makefile exists:${C_END} ${has_makefile}"
    _log "${C_WHT}Makefile has unit-test target:${C_END} ${has_makefile_target}"
    _log "${C_WHT}Unit Test Pass:${C_END} ${is_unit_tests_pass}"

    echo "QUALITY_GATE__UNIT_TEST_PASS=$is_unit_tests_pass" >>"$GITHUB_ENV"

    echo "QUALITY_GATE__UNIT_TEST_WARN_MSGS=$unit_tests_warn_msg" >>"$GITHUB_ENV"
}
