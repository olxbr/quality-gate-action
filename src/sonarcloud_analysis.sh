#!/bin/bash

source "${ACTION_PATH}/src/utils.sh"
source "${ACTION_PATH}/src/sonarcloud_client.sh"

export SONAR_PROJECT="${REPOSITORY/\//_}"
export SONAR_CHECK_TIMEOUT="${SONAR_CHECK_TIMEOUT:-60}"

# Function to update sonar project key from properties file if exists
function _update_sonar_project_key() {
    local config_file="sonar-project.properties"

    if [[ -f $config_file ]]; then
        local project_key=$(awk -F= '/^sonar.projectKey=/ {print $2}' "$config_file")

        if [ -n "$project_key" ]; then
            SONAR_PROJECT=$project_key
        fi
    fi
}

# Function to check SonarCloud Token and Component
function _check_sonarcloud_configuration() {
    _log "${C_WHT}Checking SonarCloud Configuration...${C_END}"
    _log "${C_WHT}SonarCloud Project:${C_END} ${SONAR_PROJECT}"

    local sonarcloud_warn_msg=""
    local sonarcloud_configs_ok=true

    if [[ $(_is_token_valid) == true ]]; then
        if [[ $(_is_sonarcloud_component_exists) == false ]]; then
            _log warn "${C_YEL}SonarCloud component ($SONAR_PROJECT) not found!${C_END}"
            _insert_warning_message sonarcloud_warn_msg "⚠️ SonarCloud component ($SONAR_PROJECT) not found!"
            sonarcloud_configs_ok=false
        fi
    else
        _log warn "${C_YEL}SonarCloud token is invalid!${C_END}"
        _insert_warning_message sonarcloud_warn_msg "⚠️ SonarCloud token is invalid!"
        sonarcloud_configs_ok=false
    fi

    export SONARCLOUD_CFGS_OK=$sonarcloud_configs_ok
    export QUALITY_GATE__SONARCLOUD_WARN_MSGS=$sonarcloud_warn_msg
}

# Function to check Code Coverage
function _check_coverage() {
    local coverage_passed=false
    local coverage_warn_msg=""

    if [[ $skip_coverage == false ]]; then
        _log "${C_WHT}Checking Coverage...${C_END}"

        local metric_selected='.projectStatus.conditions[] | select(.metricKey == "new_coverage")'
        local coverage_metrics=$(
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS" 2> /dev/null ||
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS_DEFAULT_BRANCH" 2> /dev/null ||
            echo ""
        )
        local coverage_status_from=$(
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS" 2> /dev/null &&
                echo "(🟢 metrics from Pull Request)" ||
                echo "(🟡 metrics from Default Branch)"
        )

        _log debug "${C_WHT}Project Status:${C_END} ${coverage_metrics}"
        _log debug "${C_WHT}Coverage Status from:${C_END} ${coverage_status_from}"
        
        if [[ -n $coverage_metrics ]]; then
            local coverage_status=$(jq -r '.status' <<<"$coverage_metrics")
            local coverage_value=$(jq -r '.actualValue' <<<"$coverage_metrics")
            local coverage_threshold=$(jq -r '.errorThreshold' <<<"$coverage_metrics")

            _log "${C_WHT}Coverage:${C_END} ${coverage_value}% ${coverage_status_from}"
            _log "${C_WHT}Coverage Threshold:${C_END} ${coverage_threshold}% ${coverage_status_from}"

            if [[ $coverage_status == "ERROR" ]]; then
                _log warn "${C_YEL}Coverage is below threshold! ${coverage_status_from}${C_END}"
                _insert_warning_message coverage_warn_msg "⚠️ Coverage is below threshold! ${coverage_status_from}"
            else
                coverage_passed=true
            fi
        else
            _log warn "${C_YEL}Coverage metrics not found!${C_END}"
            _insert_warning_message coverage_warn_msg "⚠️ Coverage metrics not found!"
        fi

        _log "${C_WHT}Coverage:${C_END} ${coverage_passed}"

    else
        _log warn "${C_YEL}Coverage check skipped!${C_END}"
        _insert_warning_message coverage_warn_msg "Coverage check skipped!"
        coverage_passed=true
    fi

    {
        echo "QUALITY_GATE__COVERAGE_PASS=$coverage_passed"
        echo "QUALITY_GATE__COVERAGE_WARN_MSGS=$coverage_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check Static Analysis
function _check_static_analysis() {
    local static_analysis_pass=false
    local static_analysis_warn_msg=""

    if [[ $skip_static_analysis == false ]]; then
        _log "${C_WHT}Checking Static Analysis...${C_END}"

        local metric_selected='.projectStatus.conditions[] | select(.metricKey != "new_coverage")'
        local static_analysis_metrics=$(
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS" 2> /dev/null ||
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS_DEFAULT_BRANCH" 2> /dev/null ||
            echo ""
        )
        local static_analysis_from=$(
            jq -er "${metric_selected}" <<<"$PROJECT_STATUS" 2> /dev/null &&
                echo "(🟢 metrics from Pull Request)" ||
                echo "(🟡 metrics from Default Branch)"
        )

        _log debug "${C_WHT}Static Analysis Metrics used:${C_END} ${static_analysis_metrics}"
        if [[ -n "$static_analysis_metrics" && $(jq 'length' <<<"$static_analysis_metrics" | uniq) -gt 0 ]]; then
            for metric in $(jq -sc '.[]' <<<"$static_analysis_metrics"); do
                _log debug "${C_WHT}Metric:${C_END} ${metric}"
                local metric_key=$(jq -r '.metricKey' <<<"$metric")
                local metric_status=$(jq -r '.status' <<<"$metric")
                local metric_value=$(jq -r '.actualValue' <<<"$metric")
                local metric_threshold=$(jq -r '.errorThreshold' <<<"$metric")

                _log "${C_WHT}Metric:${C_END} ${metric_key} ${static_analysis_from}"
                _log "${C_WHT}Value:${C_END} ${metric_value} ${static_analysis_from}"
                _log "${C_WHT}Threshold:${C_END} ${metric_threshold} ${static_analysis_from}"

                if [[ $metric_status == "ERROR" ]]; then
                    _log warn "${C_YEL}Metric is below threshold!${C_END} ${static_analysis_from}"
                    _insert_warning_message static_analysis_warn_msg "⚠️ Metric is below threshold! ${static_analysis_from}"
                else
                    static_analysis_pass=true
                fi
            done
        else
            _log warn "${C_YEL}Static Analysis metrics not found!${C_END}"
            _insert_warning_message static_analysis_warn_msg "⚠️ Static Analysis metrics not found!"
        fi

        _log "${C_WHT}Static Analysis:${C_END} ${static_analysis_pass}"

    else
        _log warn "${C_YEL}Static Analysis check skipped!${C_END}"
        _insert_warning_message static_analysis_warn_msg "Static Analysis check skipped!"
        static_analysis_pass=true
    fi

    {
        echo "QUALITY_GATE__STATIC_ANALYSIS_PASS=$static_analysis_pass"
        echo "QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS=$static_analysis_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check SonarCloud Analysis status
function _check_sonarcloud_analysis_status() {
    _log "${C_WHT}Waiting for SonarCloud Analysis...${C_END}"
    local succeeded=false

    local pull_request_infos=$(_get_pull_request_infos)

    if [[ -n $pull_request_infos ]]; then
        local commit_sha=$(jq -r '.commit.sha' <<<"$pull_request_infos")

        if [[ $commit_sha == "$PR_HEAD_SHA" ]]; then
            _log "${C_WHT}SonarCloud Analysis completed!${C_END}"
            sonarcloud_analysis_completed=true
            succeeded=true

        else
            _log "${C_WHT}SonarCloud Analysis not completed yet!${C_END}"
        fi
    fi

    $succeeded
}

# Main function to check SonarCloud Analysis
function _check_sonarcloud_analysis() {
    skip_coverage=$(_has_gate_to_skip "coverage")
    skip_static_analysis=$(_has_gate_to_skip "static_analysis")

    if [[ $skip_coverage == false || $skip_static_analysis == false ]]; then
        _update_sonar_project_key
        _check_sonarcloud_configuration

        if [[ $SONARCLOUD_CFGS_OK == true ]]; then
            local sonarcloud_analysis_completed=false
            _retry_with_delay _check_sonarcloud_analysis_status "$SONAR_CHECK_TIMEOUT"

            # Check results (Coverage and Static Analysis)
            if [[ $sonarcloud_analysis_completed ]]; then
                ## Status from PR
                export PROJECT_STATUS=$(_get_project_status "pullRequest=$PR_NUMBER")

                ## Used when coverage is not found in PR branch
                export PROJECT_STATUS_DEFAULT_BRANCH=$(_get_project_status "branch=$GITHUB_DEFAULT_BRANCH")
                
                _check_coverage
                _check_static_analysis
            else
                _log warn "${C_YEL}SonarCloud Analysis not completed!${C_END}"
                _insert_warning_message QUALITY_GATE__SONARCLOUD_WARN_MSGS "⚠️ SonarCloud Analysis not completed!"
            fi
        fi

        if [[ -n $QUALITY_GATE__SONARCLOUD_WARN_MSGS ]]; then
            {
                echo "QUALITY_GATE__COVERAGE_PASS=false"
                echo "QUALITY_GATE__COVERAGE_WARN_MSGS=$QUALITY_GATE__SONARCLOUD_WARN_MSGS"
                echo "QUALITY_GATE__STATIC_ANALYSIS_PASS=false"
                echo "QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS=$QUALITY_GATE__SONARCLOUD_WARN_MSGS"
            } >>"$GITHUB_ENV"
        fi

    else
        _log warn "${C_YEL}SonarCloud Analysis check skipped!${C_END}"
        {
            echo "QUALITY_GATE__COVERAGE_PASS=true"
            echo "QUALITY_GATE__COVERAGE_WARN_MSGS=Coverage check skipped!"
            echo "QUALITY_GATE__STATIC_ANALYSIS_PASS=true"
            echo "QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS=Static Analysis check skipped!"
        } >>"$GITHUB_ENV"
    fi
}
