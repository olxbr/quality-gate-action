#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}/src/utils.sh"
source "${ACTION_PATH}/src/sonarcloud_client.sh"

export SONAR_PROJECT="${REPOSITORY/\//_}"

# Function to format metric value
function _format_metric_value() {
    local metric_key=$1
    local metric_value=$2
    local metric_type=""

    metric_type=$(jq -r ".[] | select(.key == \"${metric_key}\") | .type" <<<"$METRICS")

    case "$metric_type" in
    "PERCENT")
        metric_value=$(printf "%.1f" "${metric_value}" | sed 's/\.0*$//')%
        ;;
    "RATING")
        case "$metric_value" in
        "1")
            metric_value="A"
            ;;
        "2")
            metric_value="B"
            ;;
        "3")
            metric_value="C"
            ;;
        "4")
            metric_value="D"
            ;;
        "5")
            metric_value="E"
            ;;
        esac
        ;;
    "WORK_DUR")
        metric_value="${metric_value}min"
        ;;
    esac

    echo "$metric_value"
}

# Function to get metric name
function _get_metric_name() {
    local metric_key=$1
    local metric_name=""

    metric_name=$(jq -r ".[] | select(.key == \"${metric_key}\") | .name" <<<"$METRICS")

    echo "$metric_name"
}

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
    export SONARCLOUD_CFGS_WARN_MSGS=$sonarcloud_warn_msg
}

# Function to check Code Coverage
function _check_coverage() {
    local coverage_passed=false
    local coverage_warn_msg=""

    if [[ $skip_coverage == false ]]; then
        _log "${C_WHT}Checking Coverage...${C_END}"
        _log "${C_WHT}Threshold:${C_END} ${COVERAGE_THRESHOLD}%"

        local pull_request_coverage_value=$(_get_coverage_measure "pullRequest=$PR_NUMBER")
        local default_branch_coverage_value=$(_get_coverage_measure "branch=$GITHUB_DEFAULT_BRANCH")

        _log "${C_WHT}Pull Request Coverage:${C_END} ${pull_request_coverage_value}%"
        _log "${C_WHT}Default Branch Coverage:${C_END} ${default_branch_coverage_value}%"

        if [[ -z $pull_request_coverage_value || -z $default_branch_coverage_value ]]; then
            _log warn "${C_YEL}Coverage metrics not found!${C_END}"
            _insert_warning_message coverage_warn_msg "⚠️ Coverage metrics not found!"
        else
            local coverage_value=$pull_request_coverage_value
            local coverage_status="OK"

            # Check if the coverage is decreasing
            if (($(echo "$pull_request_coverage_value < $default_branch_coverage_value" | bc -l))); then
                coverage_status="DECREASING"

                # Check if the coverage is below the threshold
                if (($(echo "$pull_request_coverage_value < $COVERAGE_THRESHOLD" | bc -l))); then
                    coverage_status="BELOW_THRESHOLD"
                fi
            fi

            if [[ $coverage_status == "OK" ]]; then
                coverage_passed=true
            else
                local details="<details><summary>Details</summary><ul><li>Coverage Threshold: $COVERAGE_THRESHOLD%</li><li>Default Branch Coverage: $default_branch_coverage_value%</li><li>Pull Request Coverage: $pull_request_coverage_value%</li></ul></details>"

                if [[ $coverage_status == "DECREASING" ]]; then
                    _log warn "${C_YEL}Coverage is decreasing from $default_branch_coverage_value% to $pull_request_coverage_value%!${C_END}"
                    _insert_warning_message coverage_warn_msg "⚠️ Coverage is decreasing, but still above the threshold!${details}"
                    coverage_passed=true
                fi

                if [[ $coverage_status == "BELOW_THRESHOLD" ]]; then
                    _log warn "${C_YEL}Coverage is below threshold ($COVERAGE_THRESHOLD%)!${C_END}"
                    _insert_warning_message coverage_warn_msg "⚠️ Coverage is below threshold!${details}"
                fi
            fi
        fi
    else
        _log warn "${C_YEL}Coverage check skipped!${C_END}"
        _insert_warning_message coverage_warn_msg "Coverage check skipped!"
        coverage_passed=true
    fi

    {
        echo "QUALITY_GATE__COVERAGE_PASS=$coverage_passed"
        echo "QUALITY_GATE__COVERAGE_WARN_MSGS=$coverage_warn_msg"
        echo "QUALITY_GATE__COVERAGE_VALUE=$coverage_value"
        echo "QUALITY_GATE__COVERAGE_THRESHOLD=$COVERAGE_THRESHOLD"
        echo "QUALITY_GATE__COVERAGE_STATUS=$coverage_status"
    } >>"$GITHUB_ENV"
}

# Function to check Static Analysis
function _check_static_analysis() {
    local static_analysis_pass=true
    local static_analysis_warn_msg=""
    local static_analysis_details=""
    local static_analysis_metrics_summary="[]"

    if [[ $skip_static_analysis == false ]]; then
        _log "${C_WHT}Checking Static Analysis...${C_END}"

        local project_status=$(_get_project_status "pullRequest=$PR_NUMBER")
        local project_status_default_branch=$(_get_project_status "branch=$GITHUB_DEFAULT_BRANCH")

        local metric_selected='.projectStatus.conditions[] | select(.metricKey != "new_coverage")'
        local static_analysis_metrics=$(
            jq -er "${metric_selected}" <<<"$project_status" 2>/dev/null ||
                jq -er "${metric_selected}" <<<"$project_status_default_branch" 2>/dev/null ||
                echo ""
        )
        local static_analysis_from=$(
            jq -er "${metric_selected}" <<<"$project_status" 2>/dev/null | grep -q '.' &&
                echo "${C_GRE}Metrics from [PULL REQUEST]${C_END}" ||
                echo "${C_YEL}Metrics from [DEFAULT BRANCH]${C_END}"
        )
        _log "${static_analysis_from}"

        _log debug "${C_WHT}Static Analysis Metrics used:${C_END} ${static_analysis_metrics}"
        if [[ -n "$static_analysis_metrics" && $(jq 'length' <<<"$static_analysis_metrics" | uniq) -gt 0 ]]; then

            # Get metrics definitions
            export METRICS=$(_get_metrics)

            for metric in $(jq -sc '.[]' <<<"$static_analysis_metrics"); do
                _log debug "${C_WHT}Metric:${C_END} ${metric}"

                local metric_key=$(jq -r '.metricKey' <<<"$metric")
                local metric_status=$(jq -r '.status' <<<"$metric")
                local metric_value=$(jq -r '.actualValue' <<<"$metric")
                local metric_threshold=$(jq -r '.errorThreshold' <<<"$metric")
                local metric_definition=$(jq -r ".[] | select(.key == \"${metric_key}\")" <<<"$METRICS")

                # Create consolidated metric
                local consolidated_metric=$(jq -n --argjson m "$metric" --argjson md "$metric_definition" \
                    '{
                        status: $m.status,
                        metric_key: $m.metricKey,
                        name: $md.name,
                        type: $md.type,
                        comparator: $m.comparator,
                        error_threshold: $m.errorThreshold,
                        actual_value: $m.actualValue
                    }')

                # Add consolidated metric to summary
                static_analysis_metrics_summary=$(jq -c --argjson cm "$consolidated_metric" '. += [$cm]' <<<"$static_analysis_metrics_summary")

                _log debug "${C_WHT}Metric Value:${C_END} ${metric_value}"
                _log debug "${C_WHT}Metric Threshold:${C_END} ${metric_threshold}"

                metric_value=$(_format_metric_value "$metric_key" "$metric_value")
                metric_threshold=$(_format_metric_value "$metric_key" "$metric_threshold")

                # Substitute actualValue and errorThreshold with formatted values
                metric=$(jq --arg mv "$metric_value" --arg mt "$metric_threshold" '.actualValue = $mv | .errorThreshold = $mt' <<<"$metric")

                local log_msg="${C_WHT}Metric:${C_END} ${metric_key}, ${C_WHT}Value:${C_END} ${metric_value}, ${C_WHT}Threshold:${C_END} ${metric_threshold}"

                if [[ $metric_status == "ERROR" ]]; then
                    _log warn "${log_msg} ${C_YEL}(Metric does not comply with the threshold!)${C_END}"
                    metric_name=$(_get_metric_name "$metric_key")
                    static_analysis_details+="<li>**$metric_name:** Threshold: \`$metric_threshold\`, Value: \`$metric_value\`</li>"
                else
                    _log "${log_msg}"
                fi
            done

            _log debug "${C_WHT}Static Analysis Details:${C_END} ${static_analysis_details}"
            _log debug "${C_WHT}Static Analysis Metrics Summary:${C_END} $(jq -r <<<"$static_analysis_metrics_summary")"

            if [[ -n $static_analysis_details ]]; then
                static_analysis_details="<details><summary>Details</summary><ul>$static_analysis_details</ul></details>"
                static_analysis_warn_msg="⚠️ Static Analysis metrics do not comply with the threshold!$static_analysis_details"
                static_analysis_pass=false
            fi
        else
            _log warn "${C_YEL}Static Analysis metrics not found!${C_END}"
            _insert_warning_message static_analysis_warn_msg "⚠️ Static Analysis metrics not found!"
            static_analysis_pass=false
        fi
    else
        _log warn "${C_YEL}Static Analysis check skipped!${C_END}"
        _insert_warning_message static_analysis_warn_msg "Static Analysis check skipped!"
    fi

    {
        echo "QUALITY_GATE__STATIC_ANALYSIS_PASS=$static_analysis_pass"
        echo "QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS=$static_analysis_warn_msg"
        echo "QUALITY_GATE__STATIC_ANALYSIS_METRICS=$static_analysis_metrics_summary"
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
    else
        _log "${C_WHT}SonarCloud Analysis not found yet!${C_END}"
    fi

    $succeeded
}

# Main function to check SonarCloud Analysis
function _check_sonarcloud_analysis() {
    local sonarcloud_analysis_warn_msg=""
    skip_coverage=$(_has_gate_to_skip "coverage")
    skip_static_analysis=$(_has_gate_to_skip "static_analysis")

    ## Create env vars to skip gates
    {
        echo "QUALITY_GATE__COVERAGE_SKIPPED=$skip_coverage"
        echo "QUALITY_GATE__STATIC_ANALYSIS_SKIPPED=$skip_static_analysis"
    } >>"$GITHUB_ENV"

    if [[ $skip_coverage == false || $skip_static_analysis == false ]]; then
        _update_sonar_project_key
        _check_sonarcloud_configuration

        if [[ $SONARCLOUD_CFGS_OK == true ]]; then
            local sonarcloud_analysis_completed=false
            _retry_with_delay _check_sonarcloud_analysis_status "$SONAR_CHECK_TIMEOUT"

            if [[ $sonarcloud_analysis_completed == true ]]; then
                _check_coverage
                _check_static_analysis
            else
                _log warn "${C_YEL}SonarCloud Analysis not completed!${C_END}"
                _insert_warning_message sonarcloud_analysis_warn_msg "⚠️ SonarCloud Analysis not completed!"

            fi
        else
            _insert_warning_message sonarcloud_analysis_warn_msg "$SONARCLOUD_CFGS_WARN_MSGS"
        fi

        if [[ -n $sonarcloud_analysis_warn_msg ]]; then
            _log debug "${C_YEL}SonarCloud Analysis failed!${C_END}"
            _log debug "${C_YEL}$sonarcloud_analysis_warn_msg${C_END}"

            {
                echo "QUALITY_GATE__COVERAGE_PASS=false"
                echo "QUALITY_GATE__COVERAGE_WARN_MSGS=$sonarcloud_analysis_warn_msg"
                echo "QUALITY_GATE__STATIC_ANALYSIS_PASS=false"
                echo "QUALITY_GATE__STATIC_ANALYSIS_WARN_MSGS=$sonarcloud_analysis_warn_msg"
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
