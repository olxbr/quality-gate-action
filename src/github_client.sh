#!/bin/bash

function _gh_client() {
    _log debug "${C_WHT}Executing command:${C_END}" gh api "$@"
    result=$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@")
    _log debug "${C_WHT}Result from Github API:${C_END} ${result}"
    echo "$result"
}

function _get_ruleset_ids() {
    ruleset_ids=$(_gh_client \
        /repos/"$REPOSITORY"/rulesets |
        jq -r '[.[] | select(.enforcement == "active") | .id] | join(",")' |
        grep -v '^null$')
    _log debug "${C_WHT}Ruleset IDs actived:${C_END} ${ruleset_ids}"
    echo "$ruleset_ids"
}

function _get_rules() {
    local ruleset_ids=$1

    if [ -n "$ruleset_ids" ]; then
        rules=$(_gh_client \
            "/repos/$REPOSITORY/rules/branches/$GITHUB_DEFAULT_BRANCH" |
            jq -r ".[] | select(.type == \"pull_request\" and (.ruleset_id == ($ruleset_ids) )) | .parameters" |
            grep -v '^null$')

        _log debug "${C_WHT}Rules found for id ${ruleset_ids}:${C_END} ${rules}"
        echo "$rules"
    fi
}

function _get_workflow_run_ids() {
    workflow_run_ids=$(_gh_client \
        --jq "[.workflow_runs[].id]" \
        "/repos/$REPOSITORY/actions/runs?per_page=100&head_sha=$PR_HEAD_SHA")
    echo "$workflow_run_ids"
}

function _get_quality_gate_unit_test_step() {
    local workflow_run_id=$1

    if [ -n "$workflow_run_id" ]; then
        quality_gate_step=$(_gh_client \
            "/repos/$REPOSITORY/actions/runs/$workflow_run_id/jobs" |
            jq --arg job_name "$UNIT_TEST_STEP_NAME" \
                '.jobs[].steps[] | select(.name == $job_name)' |
            grep -v '^null$')

        echo "$quality_gate_step"
    fi
}

function _get_pr_report_comment_id() {
    local comment_title="# Quality Gate"

    comment_id=$(_gh_client \
        "/repos/$REPOSITORY/issues/$PR_NUMBER/comments?per_page=100" |
        jq -r --arg comment_title "$comment_title" \
            '[.[] | select(.body | startswith($comment_title)) | .id][0]' |
        grep -v '^null$')

    echo "$comment_id"
}

function _create_pr_report_comment() {
    local report=$1

    if [ -n "$report" ]; then
        _gh_client \
            --method POST \
            --silent \
            -f body="$report" \
            /repos/"$REPOSITORY"/issues/"$PR_NUMBER"/comments
    fi
}

function _delete_pr_report_comment() {
    local comment_id=$1

    if [ -n "$comment_id" ]; then
        _gh_client \
            --method DELETE \
            --silent \
            -f body="$report" \
            /repos/"$REPOSITORY"/issues/comments/"$comment_id"
    fi
}
