#!/bin/bash

## Responsible for sending metrics to gh-metrics endpoint
## Usage:
##   submit_metrics.sh

source "${ACTION_PATH}/src/utils.sh"

# Set variables
export PR_NUM_COMMITS=$(jq -er '.pull_request.commits | select (. != null)' ${GITHUB_EVENT_PATH} || echo 0)
export PR_NUM_CHANGED_FILES=$(jq -er '.pull_request.changed_files | select (. != null)' ${GITHUB_EVENT_PATH} || echo 0)
export PR_NUM_ADDITIONS=$(jq -er '.pull_request.additions | select (. != null)' ${GITHUB_EVENT_PATH} || echo 0)
export PR_NUM_DELETIONS=$(jq -er '.pull_request.deletions | select (. != null)' ${GITHUB_EVENT_PATH} || echo 0)
export PR_CREATED_AT=$(jq -er '.pull_request.created_at | select (. != null)' ${GITHUB_EVENT_PATH} || date -u +%Y-%m-%dT%H:%M:%SZ)

ENDPOINT_URL="https://gh-hooks.olxbr.io/quality-gates/required-workflow"
DATA='{
    "repository": "${GITHUB_REPOSITORY}",
    "workflow": "${GITHUB_WORKFLOW}",
    "run_id": "${GITHUB_RUN_ID}",
    "gates_to_skip": "${GATES_TO_SKIP}",
    "num_commits": ${PR_NUM_COMMITS},
    "num_changed_files": ${PR_NUM_CHANGED_FILES},
    "num_additions": ${PR_NUM_ADDITIONS},
    "num_deletions": ${PR_NUM_DELETIONS},
    "created_at": "${PR_CREATED_AT}",
    "value": 42
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