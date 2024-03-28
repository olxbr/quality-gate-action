#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}/src/utils.sh"

# Set variables
export REPOSITORY_NAME=${GITHUB_REPOSITORY/*\//}
export PR_NUM_ID=$(jq -er '.pull_request.id' "${GITHUB_EVENT_PATH}")
export PR_NUM_COMMITS=$(jq -er '.pull_request.commits' "${GITHUB_EVENT_PATH}")
export PR_NUM_CHANGED_FILES=$(jq -er '.pull_request.changed_files' "${GITHUB_EVENT_PATH}")
export PR_NUM_ADDITIONS=$(jq -er '.pull_request.additions' "${GITHUB_EVENT_PATH}")
export PR_NUM_DELETIONS=$(jq -er '.pull_request.deletions' "${GITHUB_EVENT_PATH}")
export PR_CREATED_AT=$(jq -e '.pull_request.created_at' "${GITHUB_EVENT_PATH}")

# Normalize values
export QUALITY_GATE__COVERAGE_VALUE=${QUALITY_GATE__COVERAGE_VALUE:-null}
export QUALITY_GATE__COVERAGE_VALUE=${QUALITY_GATE__COVERAGE_VALUE/.*/} ## Remove decimal places (if any)
export QUALITY_GATE__COVERAGE_THRESHOLD=${QUALITY_GATE__COVERAGE_THRESHOLD:-null}
export QUALITY_GATE__COVERAGE_THRESHOLD=${QUALITY_GATE__COVERAGE_THRESHOLD/.*/} ## Remove decimal places (if any)
export QUALITY_GATE__STATIC_ANALYSIS_VALUE=${QUALITY_GATE__STATIC_ANALYSIS_VALUE:-null}
export QUALITY_GATE__STATIC_ANALYSIS_VALUE=${QUALITY_GATE__STATIC_ANALYSIS_VALUE/.*/} ## Remove decimal places (if any)
export QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD=${QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD:-null}
export QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD=${QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD/.*/} ## Remove decimal places (if any)
export GATES_TO_SKIP_ARR=$(_convert_to_json_array "${GATES_TO_SKIP:-}")

ENDPOINT_URL="${GH_METRICS_SERVER_ENDPOINT}/quality-gates/required-workflow"
# shellcheck disable=SC2016
DATA='{
    "repository_id": ${GITHUB_REPOSITORY_ID},
    "repository_name": "${REPOSITORY_NAME}",
    "repository_full_name": "${GITHUB_REPOSITORY}",
    "workflow_job_run_attempt": ${GITHUB_RUN_ATTEMPT},
    "pull_request_id": ${PR_NUM_ID},
    "pull_request_number": ${PR_NUMBER},
    "pull_request_created_at": ${PR_CREATED_AT},
    "pull_request_commits": ${PR_NUM_COMMITS},
    "pull_request_additions": ${PR_NUM_ADDITIONS},
    "pull_request_deletions": ${PR_NUM_DELETIONS},
    "pull_request_changed_files": ${PR_NUM_CHANGED_FILES},
    "quality_gates_to_skip_str": "${GATES_TO_SKIP}",
    "quality_gates_to_skip_arr": ${GATES_TO_SKIP_ARR},
    "quality_gate_owner_approval": ${QUALITY_GATE__OWNER_APPROVAL},
    "quality_gate_owner_approval_warn_msgs": "${QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS}",
    "quality_gate_code_review": ${QUALITY_GATE__CODE_REVIEW},
    "quality_gate_code_review_warn_msgs": "${QUALITY_GATE__CODE_REVIEW_WARN_MSGS}",
    "quality_gate_unit_test_pass": ${QUALITY_GATE__UNIT_TEST_PASS},
    "quality_gate_unit_test_warn_msgs": "${QUALITY_GATE__UNIT_TEST_WARN_MSGS}",
    "quality_gate_unit_test_skipped": ${QUALITY_GATE__UNIT_TEST_SKIPPED},
    "quality_gate_coverage_pass": ${QUALITY_GATE__COVERAGE_PASS},
    "quality_gate_coverage_warn_msgs": "${QUALITY_GATE__COVERAGE_WARN_MSGS}",
    "quality_gate_coverage_threshold": ${QUALITY_GATE__COVERAGE_THRESHOLD},
    "quality_gate_coverage_value": ${QUALITY_GATE__COVERAGE_VALUE},
    "quality_gate_coverage_status": "${QUALITY_GATE__COVERAGE_STATUS}",
    "quality_gate_coverage_skipped": ${QUALITY_GATE__COVERAGE_SKIPPED},
    "quality_gate_static_analysis_pass": ${QUALITY_GATE__STATIC_ANALYSIS_PASS},
    "quality_gate_static_analysis_warn_msgs": "${QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS}",
    "quality_gate_static_analysis_threshold": ${QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD},
    "quality_gate_static_analysis_value": ${QUALITY_GATE__STATIC_ANALYSIS_VALUE},
    "quality_gate_static_analysis_status": "${QUALITY_GATE__STATIC_ANALYSIS_STATUS}",
    "quality_gate_static_analysis_skipped": ${QUALITY_GATE__STATIC_ANALYSIS_SKIPPED},
    "quality_gate_vulnerability_pass": ${QUALITY_GATE__VULNERABILITY_PASS},
    "quality_gate_vulnerability_warn_msgs": "${QUALITY_GATE__VULNERABILITY_WARN_MSGS}",
    "quality_gate_vulnerability_skipped": ${QUALITY_GATE__VULNERABILITY_SKIPPED},
    "quality_gate_vulnerability_dependabot_alerts": ${QUALITY_GATE__VULNERABILITY_DEPENDABOT_ALERTS},
    "quality_gate_vulnerability_code_scanning_alerts": ${QUALITY_GATE__VULNERABILITY_CODE_SCANNING_ALERTS},
    "quality_gate_vulnerability_secret_scanning_alerts": ${QUALITY_GATE__VULNERABILITY_SECRET_SCANNING_ALERTS},
    "quality_gate_pass": ${QUALITY_GATE__PASS},
    "quality_gate_skip_lock": ${SKIP_QUALITY_GATE_LOCK}
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

    CURL_RES=$(eval "$CURL_CMD")

    # shellcheck disable=SC2015
    [[ "${CURL_RES}" =~ [23].. ]] &&
        _log "Data sent successfully to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}" ||
        _log erro "Failed to send data to endpoint ${ENDPOINT_URL}. Status code: ${CURL_RES}"

    _log debug "Response: $(cat ${CURL_LOG})"
    _log debug "Full log: $(cat ${CURL_ERR} | grep -v '^[\*\{\}] ')"

    ## Delete files if they exist
    rm -f "${CURL_LOG}" "${CURL_ERR}"
}
