#!/bin/bash

source ${ACTION_PATH}/src/utils.sh

# Function to log results
function _log_results() {
    #
    # Log Results
    #
    _log "╔═════════════════════╗"
    _log "║    ${C_WHT}Quality Gates${C_END}    ║"
    _log "╚═════════════════════╝"
    _log "├─────────────────────┤"
    _log "| Unit Tests     | $(print_status $QUALITY_GATE__UNIT_TEST_PASS) |"
    _log "| Code Review    | $(print_status $QUALITY_GATE__CODE_REVIEW_APPROVAL) |"
    _log "| Owner Approval | $(print_status $QUALITY_GATE__CODE_REVIEW_OWNER_APPROVAL) |"
    _log "└─────────────────────┘"
}
