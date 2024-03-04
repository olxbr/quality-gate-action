#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}/src/utils.sh"
source "${ACTION_PATH}/src/github_client.sh"

export UNIT_TEST_STEP_NAME="Quality Gate - Unit Test"
export UNIT_TEST_CHECK_TIMEOUT="${UNIT_TEST_CHECK_TIMEOUT:-60}"

# Function to get the workflow run ID containing the unit test step
function _get_workflow_run_id() {
    _log "${C_WHT}Getting Workflow Run ID...${C_END}"
    local succeeded=false

    workflow_run_ids=$(_get_workflow_run_ids)
    _log debug "${C_WHT}Found this list of Workflow Run IDs:${C_END} ${workflow_run_ids}"

    for id in $(jq -c '.[]' <<<"$workflow_run_ids"); do
        _log debug "${C_WHT}Checking Workflow Run ID:${C_END} ${id}"
        if [[ -n "$(_get_quality_gate_unit_test_step "$id")" ]]; then
            _log "${C_WHT}Workflow Run ID:${C_END} ${id}"
            workflow_run_id=$id
            succeeded=true
            break
        fi
    done

    $succeeded
}

function _check_unit_test_status() {
    _log "${C_WHT}Waiting for Unit Test...${C_END}"
    local succeeded=false

    quality_gate_step=$(_get_quality_gate_unit_test_step "$workflow_run_id")
    _log debug "${C_WHT}Quality Gate Step:${C_END} ${quality_gate_step}"

    status=$(jq -r '.status' <<<"$quality_gate_step")
    conclusion=$(jq -r '.conclusion' <<<"$quality_gate_step")

    if [[ $status == "completed" ]]; then
        succeeded=true
        if [[ $conclusion == "success" ]]; then
            _log "${C_WHT}Unit Test completed successfully!${C_END}"
            is_unit_tests_pass=true
        else
            message="Unit Test Failed!"
            _log warn "${C_YEL}${message}${C_END}"
            _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"

            _log "${C_WHT}Quality Gate Step Status:${C_END} ${status}"
            _log "${C_WHT}Quality Gate Step Conclusion:${C_END} ${conclusion}"
        fi
    else
        _log "${C_WHT}Unit Test not completed yet!${C_END}"
    fi

    $succeeded
}

function _check_unit_test_step() {
    _log "${C_WHT}Checking if Unit Test Step is present in files...${C_END}"
    is_grep_found_step_name=$(grep -qr "name:.*${UNIT_TEST_STEP_NAME}" ${GITHUB_WORKSPACE}/.github/* && echo true || echo false)

    if [[ $is_grep_found_step_name == false ]]; then
        _log "${C_WHT}Step name ($UNIT_TEST_STEP_NAME) not found in any file in workflow directory [.github]!${C_END}"

        _log "${C_WHT}Searching for referenced workflows...${C_END}"
        referenced_workflows=$(grep -hoPr '(?<=uses: ).*olxbr.*.github/workflows.*' ${GITHUB_WORKSPACE}/.github/* | uniq)

        _log "${C_WHT}Referenced workflows:${C_END} ${referenced_workflows}"
        for workflow in $referenced_workflows; do
            echo "Processing referenced workflow: $workflow"

            repo=$(echo "$workflow" | awk -F '/.github/' '{print $1}')
            file=".github/$(echo "$workflow" | awk -F '/.github/' '{print $2}' | awk -F '@' '{print $1}')"
            branch=$(echo "$workflow" | awk -F '@' '{print $2}')

            _log "${C_WHT}Repo:${C_END} ${repo} | ${C_WHT}File:${C_END} ${file} | ${C_WHT}Branch:${C_END} ${branch}"
            content_file=$(_get_repository_contents "$repo" "$file" "$branch")

            if [[ -n "$content_file" ]]; then
                is_grep_found_step_name=$(grep -q "name:.*${UNIT_TEST_STEP_NAME}" <<<"$content_file" && echo true || echo false)
                if [[ $is_grep_found_step_name == true ]]; then
                    _log "${C_WHT}Step name ($UNIT_TEST_STEP_NAME) found!${C_END}"
                    break
                fi
            fi

        done
    fi
}

# Function to check unit tests
function _check_unit_test() {
    skip_unit_tests=$(_has_gate_to_skip "unit_test")
    is_unit_tests_pass=false
    unit_tests_warn_msg=""

    if [[ $skip_unit_tests == true ]]; then
        _log warn "${C_YEL}Unit Test check skipped!${C_END}"
        _insert_warning_message unit_tests_warn_msg "Unit Test check skipped!"
        is_unit_tests_pass=true

    else
        is_grep_found_step_name=false

        _check_unit_test_step

        _log debug "is_grep_found_step_name: ${is_grep_found_step_name}"
        _log debug "Directory used to search string (${UNIT_TEST_STEP_NAME}) was ${GITHUB_WORKSPACE}/.github"
        _log debug "Count of files found with step name: [$(grep -rl "name:.*${UNIT_TEST_STEP_NAME}" ${GITHUB_WORKSPACE}/.github/* | wc -l)]"
        _log debug "List of files found with step name: [$(grep -rl "name:.*${UNIT_TEST_STEP_NAME}" ${GITHUB_WORKSPACE}/.github/*)]"
        _log debug "List of all files in directory ${GITHUB_WORKSPACE}/.github: [$(find ${GITHUB_WORKSPACE}/.github)]"

        if [[ $is_grep_found_step_name == true ]]; then
            _log "${C_WHT}Checking Unit Test...${C_END}"
            _log "${C_WHT}PR_HEAD_SHA:${C_END} ${PR_HEAD_SHA}"
            _log "${C_WHT}Step name ($UNIT_TEST_STEP_NAME) found in workflow directory [.github]!${C_END}"

            workflow_run_id=""
            _retry_with_delay _get_workflow_run_id "$UNIT_TEST_INIT_WAIT_TIMEOUT"

            if [[ -n "$workflow_run_id" ]]; then
                _retry_with_delay _check_unit_test_status "$UNIT_TEST_CHECK_TIMEOUT"
                if [[ "$status" != "completed" ]]; then
                    message="Unit Test check is not completed!"
                    _log warn "${C_YEL}${message}${C_END}"
                    _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
                fi
            else
                message="Step name ($UNIT_TEST_STEP_NAME) not found in these workflows executions. Check if the workflow is running in the correct PR event."
                _log warn "${C_YEL}${message}${C_END}"
                _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
            fi
        else
            message="Step name ($UNIT_TEST_STEP_NAME) not found in any file in workflow directory [.github]! Add it to your workflow to enable this gate."
            _log warn "${C_YEL}${message}${C_END}"
            _insert_warning_message unit_tests_warn_msg "⚠️ ${message}"
        fi
    fi

    {
        echo "QUALITY_GATE__UNIT_TEST_PASS=$is_unit_tests_pass"
        echo "QUALITY_GATE__UNIT_TEST_WARN_MSGS=$unit_tests_warn_msg"
        echo "QUALITY_GATE__UNIT_TEST_SKIPPED=$skip_unit_tests"
    } >>"$GITHUB_ENV"
}
