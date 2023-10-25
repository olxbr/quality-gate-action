#!/bin/bash

source "${ACTION_PATH}"/src/utils.sh
source "${ACTION_PATH}"/src/github_client.sh

export GH_TOKEN=${GITHUB_TOKEN}
export REPOSITORY=${GITHUB_REPOSITORY}

# Function to validate if CODEOWNERS file exists
function _validate_codeowners() {
    if [ -f "CODEOWNERS" ] || [ -f "docs/CODEOWNERS" ] || [ -f ".github/CODEOWNERS" ]; then
        echo true
    else
        echo false
    fi
}

# Function to check owner approval
function _check_owner_approval() {
    is_required_owner_approval=false
    required_owner_approval_warn_msg=""

    if [[ $skip_owner_approval == false ]]; then
        _log "${C_WHT}Checking Owner Approval...${C_END}"

        is_codeowners_file_exists=$(_validate_codeowners)
        is_required_code_owner_review=$(jq -r 'any(.[]; .require_code_owner_review == true)' <<<"$rules")

        if [[ $is_codeowners_file_exists == false ]]; then
            _log warn "${C_YEL}CODEOWNERS file not found!${C_END}"
            _insert_warning_message required_owner_approval_warn_msg "⚠️ CODEOWNERS file not found!"
        fi

        if [[ $is_required_code_owner_review == true ]]; then
            if [[ $is_codeowners_file_exists == true ]]; then
                is_required_owner_approval=true
            fi
        else
            _log warn "${C_YEL} [Require review from Code Owners] is unchecked!${C_END}"
            _insert_warning_message required_owner_approval_warn_msg "⚠️ **Require review from Code Owners** is unchecked!"
        fi

        _log "${C_WHT}Required Owner Approval:${C_END} ${is_required_owner_approval}"
        _log "${C_WHT}CODEOWNERS file exists:${C_END} $is_codeowners_file_exists"

    else
        _log warn "${C_YEL}Owner Approval check skipped!${C_END}"
        _insert_warning_message required_owner_approval_warn_msg "Owner Approval check skipped!"
        is_required_owner_approval=true
    fi

    {
        echo "QUALITY_GATE__OWNER_APPROVAL=$is_required_owner_approval"
        echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=$required_owner_approval_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check code review
function _check_code_review() {
    local is_required_code_review=false
    local required_code_review_warn_msg=""

    if [[ $skip_code_review == false ]]; then
        _log "${C_WHT}Checking Code Review...${C_END}"

        is_required_code_review=$(jq -r 'any(.[]; .required_approving_review_count > 0)' <<<"$rules")
        if [[ $is_required_code_review == false ]]; then
            _log warn "${C_YEL} [Required approvals] are less than 0!${C_END}"
            _insert_warning_message required_code_review_warn_msg "⚠️ **Required approvals** are less than 0!"
        fi

        _log "${C_WHT}Required Code Review:${C_END} ${is_required_code_review}"

    else
        _log warn "${C_YEL}Code Review check skipped!${C_END}"
        _insert_warning_message required_code_review_warn_msg "Code Review check skipped!"
        is_required_code_review=true
    fi

    {
        echo "QUALITY_GATE__CODE_REVIEW=$is_required_code_review"
        echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=$required_code_review_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check repo configs
function _check_repo_configs() {
    skip_owner_approval=$(_has_gate_to_skip "owner_approval")
    skip_code_review=$(_has_gate_to_skip "code_review")

    if [[ $skip_owner_approval == false || $skip_code_review == false ]]; then
        _log "${C_WHT}Checking Repository Configurations...${C_END}"

        _set_default_branch

        _log "${C_WHT}Repository:${C_END} ${REPOSITORY}"
        _log "${C_WHT}Default Branch:${C_END} ${DEFAULT_BRANCH}"
        _log "${C_WHT}Pull Request Number:${C_END} ${PR_NUMBER}"
        _log "${C_WHT}Pull Request Head SHA:${C_END} ${PR_HEAD_SHA}"
        _log debug "${C_WHT}Github default branch:${C_END} ${GITHUB_DEFAULT_BRANCH}" || true
        _log "Debug ${C_WHT}Github default branch:${C_END} ${GITHUB_DEFAULT_BRANCH}" || true

        ruleset_ids=$(_get_ruleset_ids)
        rules=$(_get_rules "$ruleset_ids")

        if [[ $(jq 'length > 0' <<<"$rules") == true ]]; then
            _check_owner_approval
            _check_code_review
        else
            message="No rules found for repository!"
            _log warn "${C_YEL}${message}${C_END}"
            {
                echo "QUALITY_GATE__CODE_REVIEW=false"
                echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=⚠️ $message"
                echo "QUALITY_GATE__OWNER_APPROVAL=false"
                echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=⚠️ $message"
            } >>"$GITHUB_ENV"
        fi

    else
        _log warn "${C_YEL}Repository Configurations check skipped!${C_END}"
        {
            echo "QUALITY_GATE__CODE_REVIEW=true"
            echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=Code Review check skipped!"
            echo "QUALITY_GATE__OWNER_APPROVAL=true"
            echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=Owner Approval check skipped!"
        } >>"$GITHUB_ENV"
    fi
}
