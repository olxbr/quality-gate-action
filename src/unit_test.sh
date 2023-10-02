#!/bin/bash

source "${ACTION_PATH}/src/utils.sh"
source "${ACTION_PATH}/src/github_client.sh"

export UNIT_TEST_STEP_NAME="Quality Gate - Unit Test"
export UNIT_TEST_CHECK_TIMEOUT="${UNIT_TEST_CHECK_TIMEOUT:-60}"

# Function to get the workflow run ID containing the unit test step
function _get_workflow_run_id() {
    workflow_run_ids=$(_get_workflow_run_ids)

    for id in $(jq -c '.[]' <<<"$workflow_run_ids"); do
        if [[ -n "$(_get_quality_gate_unit_test_step "$id")" ]]; then
            echo "$id"
            return
        fi
    done

    echo ""
}

# Function to check unit tests
function _check_unit_test() {
    skip_unit_tests=$(_has_gate_to_skip "unit_test")

    if [[ $skip_unit_tests == false ]]; then
        _log "${C_WHT}Checking Unit Test...${C_END}"
        _log "${C_WHT}PR_HEAD_SHA:${C_END} ${PR_HEAD_SHA}"

        is_unit_tests_pass=false
        unit_tests_warn_msg=""

        _log "${C_WHT}Waiting 5 seconds for Github to trigger workflows...${C_END}"
        sleep 5

        workflow_run_id=$(_get_workflow_run_id)

        if [[ -n "$workflow_run_id" ]]; then
            _log "${C_WHT}Workflow Run ID:${C_END} ${workflow_run_id}"

            # The time of UNIT_TEST_CHECK_TIMEOUT in minutes divide by 10 seconds
            local sleep=10
            local count=0
            local retries=$(echo "($UNIT_TEST_CHECK_TIMEOUT * 60) / $sleep" | bc)
            _log "${C_WHT}Unit Test Check Timeout:${C_END} ${UNIT_TEST_CHECK_TIMEOUT} minutes"

            _log "${C_WHT}Waiting for Unit Test...${C_END}"
            while [[ $count -lt $retries ]]; do
                quality_gate_step=$(_get_quality_gate_unit_test_step "$workflow_run_id")

                status=$(jq -r '.status' <<<"$quality_gate_step")
                conclusion=$(jq -r '.conclusion' <<<"$quality_gate_step")

                if [[ $status == "completed" ]]; then
                    if [[ $conclusion == "success" ]]; then
                        _log "${C_WHT}Unit Test completed successfully!${C_END}"
                        is_unit_tests_pass=true
                        break
                    else
                        message="Unit Test Failed!"
                        _log warn "${C_YEL}${message}${C_END}"
                        _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"

                        _log "${C_WHT}Quality Gate Step Status:${C_END} ${status}"
                        _log "${C_WHT}Quality Gate Step Conclusion:${C_END} ${conclusion}"
                        break
                    fi
                else
                    _log "${C_WHT}Unit Test not completed yet!${C_END}"
                    count=$((count + 1))
                    sleep $sleep
                fi
            done

        else
            message="Step ($UNIT_TEST_STEP_NAME) not found!"
            _log warn "${C_YEL}${message}${C_END}"
            _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
        fi
    else
        _log warn "${C_YEL}Unit Test check skipped!${C_END}"
        _insert_warning_message unit_tests_warn_msg "Unit Test check skipped!"
        is_unit_tests_pass=true
    fi

    {
        echo "QUALITY_GATE__UNIT_TEST_PASS=$is_unit_tests_pass"
        echo "QUALITY_GATE__UNIT_TEST_WARN_MSGS=$unit_tests_warn_msg"
    } >>"$GITHUB_ENV"
}
