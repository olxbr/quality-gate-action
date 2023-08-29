#!/bin/bash

source "${ACTION_PATH}"/src/utils.sh
source "${ACTION_PATH}"/src/github_client.sh

export GH_TOKEN=${GITHUB_TOKEN}
export REPOSITORY=${GITHUB_REPOSITORY}
export PR_NUMBER=${GITHUB_PR_NUMBER}

# Function to return status badge configuration
function _get_status_badge() {
    if [ "$QUALITY_GATE__UNIT_TEST_PASS" = true ] &&
        [ "$QUALITY_GATE__CODE_REVIEW_APPROVAL" = true ] &&
        [ "$QUALITY_GATE__CODE_REVIEW_OWNER_APPROVAL" = true ]; then
        echo "Passed!-26a641"
    else
        echo "Failed!-c93c37"
    fi
}

# Function to convert boolean to emoji
function _boolean_to_emoji() {
    if [ "$1" = true ]; then
        echo -e "\xE2\x9C\x85"
    else
        echo -e "\xE2\x9D\x8C"
    fi
}

# Function to log results
function _log_results() {
    _log "${C_WHT}REPORT${C_END}"

    _log "╔═════════════════════╗"
    _log "║    ${C_WHT}Quality Gates${C_END}    ║"
    _log "╚═════════════════════╝"
    _log "├─────────────────────┤"
    _log "| Unit Tests     | ${QUALITY_GATE__UNIT_TEST_EMOJI} |"
    _log "| Code Review    | ${QUALITY_GATE__CODE_REVIEW_EMOJI} |"
    _log "| Owner Approval | ${QUALITY_GATE__OWNER_APPROVAL_EMOJI} |"
    _log "└─────────────────────┘"
}

# Function to write github actions summary
function _write_github_actions_summary() {
    _log "${C_WHT}Writing GitHub Actions Summary...${C_END}"

    report=${REPORT_TEMPLATE}
    report="${report@Q}"
    report="${report#\$\'}"
    report="${report%\'}"
    report=$(envsubst "$(printf '${%s} ' $(env | cut -d'=' -f1))" <<<"${report}")

    echo -e "${report}" >>"$GITHUB_STEP_SUMMARY"
}

# Function to post report as PR comment
function _post_pr_comment() {
    if [ -n "$PR_NUMBER" ]; then
        _log "${C_WHT}Posting PR comment...${C_END}"
        _log "${C_WHT}PR Number:${C_END} ${PR_NUMBER}"

        report=$(envsubst <<<"${REPORT_TEMPLATE}")
        comment_id=$(_get_pr_report_comment_id)

        _log "${C_WHT}PR Comment ID:${C_END} ${comment_id}"

        if [ -n "$comment_id" ]; then
            _log "${C_WHT}Updating an existing PR comment...${C_END}"
            _update_pr_report_comment "$comment_id" "$report"
        else
            _log "${C_WHT}Creating PR comment...${C_END}"
            _create_pr_report_comment "$report"
        fi
    else
        _log warn "${C_YEL}Not a PR so no comment will be posted!${C_END}"
    fi
}

# Function to send report
function _send_report() {
    export QUALITY_GATE__UNIT_TEST_EMOJI=$(_boolean_to_emoji "$QUALITY_GATE__UNIT_TEST_PASS")
    export QUALITY_GATE__CODE_REVIEW_EMOJI=$(_boolean_to_emoji "$QUALITY_GATE__CODE_REVIEW_APPROVAL")
    export QUALITY_GATE__OWNER_APPROVAL_EMOJI=$(_boolean_to_emoji "$QUALITY_GATE__CODE_REVIEW_OWNER_APPROVAL")

    export QUALITY_GATE__UNIT_TEST_DESCRIPTION=${QUALITY_GATE__UNIT_TEST_WARN_MSGS:-"Passed!"}
    export QUALITY_GATE__CODE_REVIEW_DESCRIPTION=${QUALITY_GATE__CODE_REVIEW_WARN_MSGS:-"Passed!"}
    export QUALITY_GATE__OWNER_APPROVAL_DESCRIPTION=${QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS:-"Passed!"}

    export STATUS_BADGE=$(_get_status_badge)

    export REPORT_TEMPLATE=$(cat "${ACTION_PATH}"/src/templates/report.md)

    _log_results
    _write_github_actions_summary
    _post_pr_comment
}
