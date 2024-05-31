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
export QUALITY_GATE__VULNERABILITY_DEPENDABOT_ALERTS=${QUALITY_GATE__VULNERABILITY_DEPENDABOT_ALERTS:-null}
export QUALITY_GATE__VULNERABILITY_CODE_SCANNING_ALERTS=${QUALITY_GATE__VULNERABILITY_CODE_SCANNING_ALERTS:-null}
export QUALITY_GATE__VULNERABILITY_SECRET_SCANNING_ALERTS=${QUALITY_GATE__VULNERABILITY_SECRET_SCANNING_ALERTS:-null}
export GATES_TO_SKIP_ARR=$(_convert_to_json_array "${GATES_TO_SKIP:-}")

ENDPOINT_URL="${GH_METRICS_SERVER_ENDPOINT}/quality-gates/required-workflow"
# shellcheck disable=SC2016

# CAUTION! 
# Please don't edit the PAYLOAD variable or delete its comments; they're needed for creating the metrics documentation.
PAYLOAD='{
    "repository_id": ${GITHUB_REPOSITORY_ID}, ## long | Repository ID
    "repository_name": "${REPOSITORY_NAME}", ## string | Repository name
    "repository_full_name": "${GITHUB_REPOSITORY}", ## string | Repository full name (org/repo)
    "workflow_job_run_attempt": ${GITHUB_RUN_ATTEMPT}, ## long | Quality Gates workflow execution attempts
    "pull_request_id": ${PR_NUM_ID}, ## long | Pull request ID
    "pull_request_number": ${PR_NUMBER}, ## long | Pull request number
    "pull_request_created_at": ${PR_CREATED_AT}, ## long | Pull request created at (timestamp)
    "pull_request_commits": ${PR_NUM_COMMITS}, ## long | Number of pull request commits
    "pull_request_additions": ${PR_NUM_ADDITIONS}, ## long | Number of pull request additions
    "pull_request_deletions": ${PR_NUM_DELETIONS}, ## long | Number of pull request deletions
    "pull_request_changed_files": ${PR_NUM_CHANGED_FILES}, ## long | Number of pull request changed files
    "quality_gates_to_skip_str": "${GATES_TO_SKIP}", ## string | String with all gates skipped, registered as a repository variable 
    "quality_gates_to_skip_arr": ${GATES_TO_SKIP_ARR}, ## array[string] | Same as GATES_TO_SKIP, but as an array
    "quality_gate_owner_approval": ${QUALITY_GATE__OWNER_APPROVAL_PASS}, ## boolean | Indicates if owner approval has been configured and passed successfully
    "quality_gate_owner_approval_warn_msgs": "${QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_code_review": ${QUALITY_GATE__CODE_REVIEW_PASS}, ## boolean | Indicates if code review has been configured and passed successfully
    "quality_gate_code_review_warn_msgs": "${QUALITY_GATE__CODE_REVIEW_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_unit_test_pass": ${QUALITY_GATE__UNIT_TEST_PASS}, ## boolean | Indicates if unit test has been configured and passed successfully
    "quality_gate_unit_test_warn_msgs": "${QUALITY_GATE__UNIT_TEST_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_unit_test_skipped": ${QUALITY_GATE__UNIT_TEST_SKIPPED}, ## boolean | Indicates if unit test has been skipped
    "quality_gate_coverage_pass": ${QUALITY_GATE__COVERAGE_PASS}, ## boolean | Indicates if coverage has been configured and passed successfully
    "quality_gate_coverage_warn_msgs": "${QUALITY_GATE__COVERAGE_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_coverage_threshold": ${QUALITY_GATE__COVERAGE_THRESHOLD}, ## long | The minimum acceptable value defined for all repositories (When we have repository criticality, we will have this value different for each criticality)
    "quality_gate_coverage_value": ${QUALITY_GATE__COVERAGE_VALUE}, ## long | The quality gate coverage actual value
    "quality_gate_coverage_status": "${QUALITY_GATE__COVERAGE_STATUS}", ## string | Indicates the status of the coverage gate in relation to the current coverage of the default branch and the threshold.<br><br>We currently have 3 statuses:<ul><li>`OK` - Everything as expected (coverage equal to or above the default branch)</li><li>`DECREASING` - Coverage has decreased compared to what we have in the default branch</li><li>`BELOW_THRESHOLD` - It is below the minimum acceptable value</li></ul>
    "quality_gate_coverage_skipped": ${QUALITY_GATE__COVERAGE_SKIPPED}, ## boolean | Indicates if coverage has been skipped
    "quality_gate_static_analysis_pass": ${QUALITY_GATE__STATIC_ANALYSIS_PASS}, ## boolean | Indicates if static analysis has been configured and passed successfully
    "quality_gate_static_analysis_warn_msgs": "${QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_static_analysis_threshold": ${QUALITY_GATE__STATIC_ANALYSIS_THRESHOLD}, ## long | ⚠️ Warning! This metric is wrong! It is the last threshold from a list of static analysis metrics. It must be removed or fixed.
    "quality_gate_static_analysis_value": ${QUALITY_GATE__STATIC_ANALYSIS_VALUE}, ## long | ⚠️ Warning! This metric is wrong! It is the last value from a list of static analysis metrics. It must be removed or fixed.
    "quality_gate_static_analysis_status": "${QUALITY_GATE__STATIC_ANALYSIS_STATUS}", ## string | ⚠️ Warning! This metric is wrong! It is the last status from a list of static analysis metrics. It must be removed or fixed.
    "quality_gate_static_analysis_skipped": ${QUALITY_GATE__STATIC_ANALYSIS_SKIPPED}, ## boolean | Indicates if static analysis has been skipped
    "quality_gate_vulnerability_pass": ${QUALITY_GATE__VULNERABILITY_PASS}, ## boolean | Indicates if `Security and Code Analysis` has been configured and the vulnerability gate has been passed successfully
    "quality_gate_vulnerability_warn_msgs": "${QUALITY_GATE__VULNERABILITY_WARN_MSGS}", ## string | Alert messages indicating reasons why the gate was not passed or was passed with reservations
    "quality_gate_vulnerability_skipped": ${QUALITY_GATE__VULNERABILITY_SKIPPED}, ## boolean | Indicates if vulnerability has been skipped
    "quality_gate_vulnerability_dependabot_alerts": ${QUALITY_GATE__VULNERABILITY_DEPENDABOT_ALERTS}, ## long | Github dependabot alerts for the repository
    "quality_gate_vulnerability_code_scanning_alerts": ${QUALITY_GATE__VULNERABILITY_CODE_SCANNING_ALERTS}, ## long | Github code scanning alerts for the repository
    "quality_gate_vulnerability_secret_scanning_alerts": ${QUALITY_GATE__VULNERABILITY_SECRET_SCANNING_ALERTS}, ## long | Github secret scanning alerts for the repository
    "quality_gate_pass": ${QUALITY_GATE__PASS}, ## boolean | Indicates if all quality gates have been passed
    "quality_gate_skip_lock": ${SKIP_QUALITY_GATE_LOCK} ## boolean | Indicates if pull request locking by not passing quality gates has been skipped
}'

# Remove comments from payload
DATA=$(echo "$PAYLOAD" | sed 's/##.*//g')

# Replace variables in data
DATA=$(envsubst <<<"$DATA")

# Send data to endpoint
CURL_LOG="curl.log"
CURL_ERR="curl.err"
CURL_CMD="curl -svL --connect-timeout 5 --write-out '%{http_code}' -X POST -H 'Content-Type: application/json' '$ENDPOINT_URL' -d '$DATA' -o ${CURL_LOG} 2> ${CURL_ERR}"

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
