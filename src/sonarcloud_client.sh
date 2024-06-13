#!/bin/bash

function _is_token_valid() {
    response_cmd="curl -s -u '${SONAR_TOKEN}': \
        https://sonarcloud.io/api/authentication/validate"

    _log debug "${C_WHT}Executing command:${C_END} ${response_cmd}"
    response=$(eval ${response_cmd})

    _log debug "${C_WHT}Return of execution:${C_END} ${response}"
    echo "$response" | jq -r '.valid'
}

function _is_sonarcloud_component_exists() {
    response_code_cmd="curl -s -o /dev/null -w '%{http_code}' \
        -u '${SONAR_TOKEN}': \
        -d 'component=${SONAR_PROJECT}' \
        https://sonarcloud.io/api/components/show"

    _log debug "${C_WHT}Executing command:${C_END} ${response_code_cmd}"
    response_code=$(eval ${response_code_cmd})

    _log debug "${C_WHT}Return of execution:${C_END} ${response_code}"
    if [ "$response_code" = "200" ]; then
        _is_exists=true
    else
        _is_exists=false
    fi

    _log debug "${C_WHT}SonarCloud component exists:${C_END} ${_is_exists}"
    echo "$_is_exists"
}

function _get_pull_request_infos() {
    pull_requests_cmd="curl -s -u '${SONAR_TOKEN}': \
        -d 'project=${SONAR_PROJECT}' \
        https://sonarcloud.io/api/project_pull_requests/list"

    _log debug "${C_WHT}Executing command:${C_END} ${pull_requests_cmd}"
    pull_requests=$(eval ${pull_requests_cmd})

    _log debug "${C_WHT}Return of execution:${C_END} ${pull_requests}"
    echo "$pull_requests" | jq ".pullRequests[] | select(.key == \"$PR_NUMBER\")"
}

function _get_project_status() {
    filter_parameter="$1"

    project_status_cmd="curl -s -u '${SONAR_TOKEN}:' \
        -d 'projectKey=${SONAR_PROJECT}' \
        -d '${filter_parameter}' \
        https://sonarcloud.io/api/qualitygates/project_status"

    _log debug "${C_WHT}Executing command:${C_END} ${project_status_cmd}"
    project_status=$(eval ${project_status_cmd})

    _log debug "${C_WHT}Return of execution:${C_END} ${project_status}"
    echo "$project_status"
}

function _get_coverage_measure() {
    filter_parameter="$1"

    coverage_cmd="curl -s -u '${SONAR_TOKEN}:' \
        -d 'component=${SONAR_PROJECT}' \
        -d 'metricKeys=coverage' \
        -d '${filter_parameter}' \
        https://sonarcloud.io/api/measures/component"

    _log debug "${C_WHT}Executing command:${C_END} ${coverage_cmd}"
    coverage=$(eval "${coverage_cmd}")

    _log debug "${C_WHT}Return of execution:${C_END} ${coverage}"
    echo "$coverage" | jq -r '.component.measures[0].value'
}

function _get_metrics() {
    metrics_cmd="curl -s -u '${SONAR_TOKEN}:' \
        -d 'ps=500' \
        https://sonarcloud.io/api/metrics/search"

    _log debug "${C_WHT}Executing command:${C_END} ${metrics_cmd}"
    metrics=$(eval "${metrics_cmd}")

    _log debug "${C_WHT}Return of execution:${C_END} ${metrics}"
    echo "$metrics" | jq -r '.metrics'
}
