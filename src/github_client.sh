#!/bin/bash

function _get_ruleset_ids() {
    ruleset_ids=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq "[.[] | select(.enforcement == \"active\") | .id] | join(\",\")" \
        /repos/"$REPOSITORY"/rulesets)
    echo "$ruleset_ids"
}

function _get_rules() {
    local ruleset_ids=$1

    if [ -n "$ruleset_ids" ]; then
        rules=$(gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --jq ".[] | select(.type == \"pull_request\" and (.ruleset_id == ($ruleset_ids) )) | .parameters" \
            /repos/"$REPOSITORY"/rules/branches/$GITHUB_DEFAULT_BRANCH)

        echo $rules | jq -s
    fi
}

function _get_pr_report_comment_id() {
    local comment_title="# Quality Gate"

    comment_id=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq "[.[] | select(.body | startswith(\"$comment_title\")) | .id][0]" \
        "/repos/$REPOSITORY/issues/$PR_NUMBER/comments?per_page=100")

    echo "$comment_id"
}

function _create_pr_report_comment() {
    local report=$1

    if [ -n "$report" ]; then
        gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -X POST \
            --silent \
            -f body="$report" \
            /repos/"$REPOSITORY"/issues/"$PR_NUMBER"/comments
    fi
}

function _update_pr_report_comment() {
    local comment_id=$1
    local report=$2

    if [ -n "$comment_id" ] && [ -n "$report" ]; then
        gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --method PATCH \
            --silent \
            -f body="$report" \
            /repos/"$REPOSITORY"/issues/comments/"$comment_id"
    fi
}

function _get_workflow_run_ids() {
    workflow_run_ids=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --jq "[.workflow_runs[].id]" \
        "/repos/$REPOSITORY/actions/runs?per_page=100&head_sha=$PR_HEAD_SHA")
    echo "$workflow_run_ids"
}

function _get_quality_gate_unit_test_step() {
    local workflow_run_id=$1

    if [ -n "$workflow_run_id" ]; then
        quality_gate_step=$(gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --jq ".jobs[].steps[] | select(.name == \"$UNIT_TEST_STEP_NAME\")" \
            "/repos/$REPOSITORY/actions/runs/$workflow_run_id/jobs")

        echo "$quality_gate_step"
    fi
}
