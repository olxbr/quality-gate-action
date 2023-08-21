#!/bin/bash

source ${ACTION_PATH}/src/utils.sh

DEFAULT_BRANCH=main

function _set_default_branch(){
    default_branch=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq ".default_branch" \
        /repos/$REPOSITORY)

    DEFAULT_BRANCH=$default_branch
}

function _get_ruleset_ids() {
    ruleset_ids=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq "[.[] | select(.enforcement == \"active\") | .id] | join(\",\")" \
        /repos/$REPOSITORY/rulesets)
    echo $ruleset_ids
}

function _get_rules() {
    local ruleset_ids=$1

    if [ -n "$ruleset_ids" ]; then
        rules=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq ".[] | select(.type == \"pull_request\" and (.ruleset_id == ("$ruleset_ids") )) | .parameters" \
        /repos/$REPOSITORY/rules/branches/$DEFAULT_BRANCH)

        echo $rules | jq -s
    fi
}
