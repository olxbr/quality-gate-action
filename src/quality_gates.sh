#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}"/src/utils.sh

export SKIP_QUALITY_GATE_LOCK="${SKIP_QUALITY_GATE_LOCK:-false}"

function _check_quality_gates() {
    if [ "$SKIP_QUALITY_GATE_LOCK" = true ]; then
        _log warn "${C_YEL}Skipping Quality Gate Locks!${C_END}"
        echo "::warning::Skipping Quality Gate Locks!"
        return
    fi

    _log "${C_WHT}Checking Quality Gates...${C_END}"
    local lock_pull_request=false

    if [ "$QUALITY_GATE__UNIT_TEST_PASS" = false ]; then
        _log erro "${C_WHT}Unit tests failed!"
    fi

    if [ "$QUALITY_GATE__CODE_REVIEW_PASS" = false ]; then
        _log erro "${C_WHT}Code review failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__OWNER_APPROVAL_PASS" = false ]; then
        _log erro "${C_WHT}Owner approval failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__COVERAGE_PASS" == false ]; then
        _log erro "${C_WHT}Coverage failed!${C_END}"
        lock_pull_request=true
    fi

    if [ "$QUALITY_GATE__STATIC_ANALYSIS_PASS" == false ]; then
        _log erro "${C_WHT}Static analysis failed!${C_END}"
    fi

    if [ "$QUALITY_GATE__VULNERABILITY_PASS" == false ]; then
        _log erro "${C_WHT}Vulnerability failed!${C_END}"
    fi

    if [ "$lock_pull_request" = true ]; then
        echo "::error::Pull request is locked! Please fix the issues and try again."
        exit 1
    fi
}
