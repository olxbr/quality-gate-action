#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}"/src/utils.sh

function _check_quality_gates() {
    _log info "${C_WHT}Checking Quality Gates...${C_END}"
    local lock_pull_request=false

    if [ "$QUALITY_GATE__UNIT_TEST_PASS" = false ]; then
        _log error "${C_RED}Unit tests failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__CODE_REVIEW_PASS" = false ]; then
        _log error "${C_RED}Code review failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__OWNER_APPROVAL_PASS" = false ]; then
        _log error "${C_RED}Owner approval failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__COVERAGE_PASS" == false ]; then
        _log error "${C_RED}Coverage failed!${C_END}"
        lock_pull_request=true
    fi

    if [ "$QUALITY_GATE__STATIC_ANALYSIS_PASS" == false ]; then
        _log error "${C_RED}Static analysis failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__VULNERABILITY_PASS" == false ]; then
        _log error "${C_RED}Vulnerability failed!${C_END}"
    fi

    if [ "$lock_pull_request" = true ]; then
        _log error "${C_RED}Pull request is locked!${C_END}"
        echo "::error::Pull request is locked! Please fix the issues and try again."
        exit 1
    fi
}
