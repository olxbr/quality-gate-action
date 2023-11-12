#!/bin/bash

## Responsible for sending metrics to gh-metrics endpoint
## Usage:
##   submit_metrics.sh

source "${ACTION_PATH}/src/utils.sh"

# Set variables
ENDPOINT_URL="https://gh-hooks.olxbr.io/quality-gates/required-workflow"
DATA='{
    "repository": "${GITHUB_REPOSITORY}",
    "workflow": "${GITHUB_WORKFLOW}",
    "run_id": "${GITHUB_RUN_ID}",
    "gates_to_skip": "${GATES_TO_SKIP}",
    "num_commits": ${{ github.event.pull_request.commits }},
    "num_changed_files": ${{ github.event.pull_request.changed_files }},
    "num_additions": ${{ github.event.pull_request.additions }},
    "num_deletions": ${{ github.event.pull_request.deletions }},
    "created_at": "${{ github.event.pull_request.created_at }}",
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
}