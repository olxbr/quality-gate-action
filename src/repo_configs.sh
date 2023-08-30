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

# Function to check repo configs
function _check_repo_configs() {
    _log "${C_WHT}Checking Repository Configurations...${C_END}"

    _set_default_branch

    _log "${C_WHT}Repository:${C_END} ${REPOSITORY}"
    _log "${C_WHT}Default Branch:${C_END} ${DEFAULT_BRANCH}"

    is_required_code_review_approval=false
    is_required_code_owner_approval=false

    required_code_review_warn_msg=""
    required_code_owner_warn_msg=""

    is_codeowners_file_exists=$(_validate_codeowners)
    if [[ $is_codeowners_file_exists == false ]]; then
        message="CODEOWNERS file not found!"
        _log warn "${C_YEL}${message}${C_END}"
        _insert_warning_message required_code_owner_warn_msg "⚠️ ${message}"
    fi

    ruleset_ids=$(_get_ruleset_ids)
    rules=$(_get_rules "$ruleset_ids")

    if [[ $(jq 'length > 0' <<<"$rules") == true ]]; then
        is_required_code_review_approval=$(jq -r 'any(.[]; .required_approving_review_count > 0)' <<<"$rules")
        is_required_code_owner_review=$(jq -r 'any(.[]; .require_code_owner_review == true)' <<<"$rules")

        if [[ $is_required_code_owner_review == true ]]; then
            if [[ $is_codeowners_file_exists == true ]]; then
                is_required_code_owner_approval=true
            fi
        else
            _log warn "${C_YEL} [Require Code Owner Review] rule is disabled!${C_END}"
            _insert_warning_message required_code_owner_warn_msg "⚠️ **Require Code Owner Review** rule is disabled!"
        fi

        _log "${C_WHT}Required Code Review Approval:${C_END} ${is_required_code_review_approval}"
        _log "${C_WHT}Required Code Owner Approval:${C_END} ${is_required_code_owner_approval}"
        _log "${C_WHT}CODEOWNERS file exists:${C_END} $is_codeowners_file_exists"
    else
        message="No rules found for repository!"
        _log warn "${C_YEL}${message}${C_END}"
        _insert_warning_message required_code_review_warn_msg "⚠️ ${message}"
        _insert_warning_message required_code_owner_warn_msg "⚠️ ${message}"
    fi

    echo "QUALITY_GATE__CODE_REVIEW_APPROVAL=$is_required_code_review_approval" >>"$GITHUB_ENV"
    echo "QUALITY_GATE__CODE_REVIEW_OWNER_APPROVAL=$is_required_code_owner_approval" >>"$GITHUB_ENV"

    echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=$required_code_review_warn_msg" >>"$GITHUB_ENV"
    echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=$required_code_owner_warn_msg" >>"$GITHUB_ENV"
}
