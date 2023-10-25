#!/bin/bash

function _is_token_valid() {
    response=$(curl -s -u "${SONAR_TOKEN}": \
        https://sonarcloud.io/api/authentication/validate)

    echo "$response" | jq -r '.valid'
}

function _is_sonarcloud_component_exists() {
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "${SONAR_TOKEN}": \
        -d "component=${SONAR_PROJECT}" \
        https://sonarcloud.io/api/components/show)

    if [ "$response_code" = "200" ]; then
        echo true
    else
        echo false
    fi
}

function _get_pull_request_infos() {
    pull_requests=$(curl -s -u "${SONAR_TOKEN}": \
        -d "project=${SONAR_PROJECT}" \
        https://sonarcloud.io/api/project_pull_requests/list)

    echo "$pull_requests" | jq ".pullRequests[] | select(.key == \"$PR_NUMBER\")"
}

function _get_project_status() {
    filter_parameter="pullRequest=$PR_NUMBER"

    ## If default branch was passed, then use it to get the project status
    default_branch=$1
    if [[ -n "$default_branch" ]]; then
        filter_parameter="branch=$default_branch"
    fi

    project_status=$(curl -s -u "${SONAR_TOKEN}": \
        -d "projectKey=${SONAR_PROJECT}" \
        -d "${filter_parameter}" \
        https://sonarcloud.io/api/qualitygates/project_status)

    echo "$project_status"
}
