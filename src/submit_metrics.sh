#!/bin/bash

## Responsible for sending metrics to gh-metrics endpoint
## Usage:
##   submit_metrics.sh

source "${ACTION_PATH}/src/utils.sh"

# Set variables
ENDPOINT_URL="https://gh-hooks.olxbr.io/quality-gates/required-workflow"
DATA="{\"metric_name\": \"example_metric\", \"value\": 42}"

# Send data to endpoint
CURL_LOG="curl.log"
CURL_ERR="curl.err"
CURL_CMD="curl -sv --connect-timeout 5 --write-out '%{http_code}' -X POST -H 'Content-Type: application/json' -d '$DATA' '$ENDPOINT_URL' -o ${CURL_LOG} 2> ${CURL_ERR}"

_log "Sending data to endpoint..."
_log debug "Executing command: $CURL_CMD"
CURL_RES=$(eval $CURL_CMD)

if [[ "${CURL_RES}" =~ [23].. ]]; then
    _log "Data sent successfully to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}"
else
    _log error "Failed to send data to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}"
fi

_log debug "Response: $(cat ${CURL_LOG})"
_log debug "Full log: $(cat ${CURL_ERR})"

env

## Delete files if they exist
rm -f "${CURL_LOG}" "${CURL_ERR}"