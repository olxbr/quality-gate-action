#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}"/src/utils.sh

function _check_quality_gates() {
    _log info "${C_WHT}Checking Quality Gates...${C_END}"
    local lock_pull_request=false

    if [ "$QUALITY_GATE__UNIT_TEST_PASS" = false ]; then
        _log erro "Unit tests failed!"
    fi

    if [ "$QUALITY_GATE__CODE_REVIEW_PASS" = false ]; then
        _log erro "Code review failed!"
    fi

    if [ "$QUALITY_GATE__OWNER_APPROVAL_PASS" = false ]; then
        _log erro "Owner approval failed!"
    fi

    if [ "$QUALITY_GATE__COVERAGE_PASS" == false ]; then
        _log erro "Coverage failed!"
        lock_pull_request=true
    fi

    if [ "$QUALITY_GATE__STATIC_ANALYSIS_PASS" == false ]; then
        _log erro "Static analysis failed!"
    fi

    if [ "$QUALITY_GATE__VULNERABILITY_PASS" == false ]; then
        _log erro "Vulnerability failed!"
    fi

    if [ "$lock_pull_request" = true ]; then
        _log error "${C_RED}Pull request is locked!${C_END}"
        echo "::error::Pull request is locked! Please fix the issues and try again."
        exit 1
    fi
}
