#!/bin/bash

## Responsible for sending metrics to gh-metrics endpoint
## Usage:
##   submit_metrics.sh

source "${ACTION_PATH}/src/utils.sh"

# Set variables
export PR_NUM_COMMITS=$(jq -er '.pull_request.commits' ${GITHUB_EVENT_PATH})
export PR_NUM_CHANGED_FILES=$(jq -er '.pull_request.changed_files' ${GITHUB_EVENT_PATH})
export PR_NUM_ADDITIONS=$(jq -er '.pull_request.additions' ${GITHUB_EVENT_PATH})
export PR_NUM_DELETIONS=$(jq -er '.pull_request.deletions' ${GITHUB_EVENT_PATH})
export PR_CREATED_AT=$(jq -e '.pull_request.created_at' ${GITHUB_EVENT_PATH})

ENDPOINT_URL="https://gh-hooks.olxbr.io/quality-gates/required-workflow"
DATA='{
    "repository": "${GITHUB_REPOSITORY}",
    "workflow": "${GITHUB_WORKFLOW}",
    "gates_to_skip": "${GATES_TO_SKIP}",
    "created_at": ${PR_CREATED_AT},
    "num_pull_requests": ${PR_NUMBER},
    "num_commits": ${PR_NUM_COMMITS},
    "num_changed_files": ${PR_NUM_CHANGED_FILES},
    "num_additions": ${PR_NUM_ADDITIONS},
    "num_deletions": ${PR_NUM_DELETIONS},
    "qg_owner_approval": ${QUALITY_GATE__OWNER_APPROVAL},
    "qg_owner_approval_warn_msgs": "${QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS}",
    "qg_code_review": ${QUALITY_GATE__CODE_REVIEW},
    "qg_code_review_warn_msgs": "${QUALITY_GATE__CODE_REVIEW_WARN_MSGS}",
    "qg_unit_test_pass": ${QUALITY_GATE__UNIT_TEST_PASS},
    "qg_unit_test_warn_msgs": "${QUALITY_GATE__UNIT_TEST_WARN_MSGS}",
    "qg_code_coverage_pass": ${QUALITY_GATE__CODE_COVERAGE_PASS},
    "qg_code_coverage_warn_msgs": "${QUALITY_GATE__CODE_COVERAGE_WARN_MSGS}",
    "gq_static_analysis_pass": ${QUALITY_GATE__STATIC_ANALYSIS_PASS},
    "qg_static_analysis_warn_msgs": "${QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS}"
}'

# Replace variables in data
DATA=$(envsubst <<<"$DATA")

# Send data to endpoint
CURL_LOG="curl.log"
CURL_ERR="curl.err"
CURL_CMD="curl -sv --connect-timeout 5 --write-out '%{http_code}' -X POST -H 'Content-Type: application/json' '$ENDPOINT_URL' -d '$DATA' -o ${CURL_LOG} 2> ${CURL_ERR}"

## MAIN ##
function _submit_metrics() {
    _log "Sending data to endpoint..."
    _log debug "Executing command: $CURL_CMD"
    CURL_RES=$(eval $CURL_CMD)

    if [[ "${CURL_RES}" =~ [23].. ]]; then
        _log "Data sent successfully to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}"
    else
        _log erro "Failed to send data to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}"
    fi

    _log debug "Response: $(cat ${CURL_LOG})"
    _log debug "Full log: $(cat ${CURL_ERR} | grep -v '^[\*\{\}] ')"

    env

    ## Delete files if they exist
    rm -f "${CURL_LOG}" "${CURL_ERR}"

    cat ${GITHUB_EVENT_PATH} | jq
}