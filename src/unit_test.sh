#!/bin/bash

source ${ACTION_PATH}/src/utils.sh

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

    has_makefile=$(_validate_makefile)

    if [[ $has_makefile == true ]]; then
        has_makefile_target=$(_validate_makefile_target)

        if [[ $has_makefile_target == true ]]; then
            _log "${C_WHT}Running Unit Test...${C_END}"

            make unit-test && is_unit_tests_pass=true || true

            _log "${C_WHT}Unit Test Pass:${C_END} ${is_unit_tests_pass}"
        else
            _log warn "${C_YEL}No unit-test target found in Makefile!${C_END}"
        fi
    else
        _log warn "${C_YEL}No Makefile found!${C_END}"
    fi

    echo "QUALITY_GATE__UNIT_TEST_PASS=$is_unit_tests_pass" >>"$GITHUB_ENV"
}
