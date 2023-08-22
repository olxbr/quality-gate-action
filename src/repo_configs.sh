#!/bin/bash

source ${ACTION_PATH}/src/utils.sh
source ${ACTION_PATH}/src/github_client.sh

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

    ruleset_ids=$(_get_ruleset_ids)
    rules=$(_get_rules "$ruleset_ids")

    if [[ $(jq 'length > 0' <<<"$rules") == true ]]; then
        is_required_code_review_approval=$(jq -r 'any(.[]; .required_approving_review_count > 0)' <<<"$rules")
        is_required_code_owner_approval=$(jq -r 'any(.[]; .require_code_owner_review == true)' <<<"$rules")

        if [[ $is_required_code_owner_approval == true ]]; then
            if [[ $(_validate_codeowners) == false ]]; then
                _log warn "${C_YEL}CODEOWNERS file not found!${C_END}"
                is_required_code_owner_approval=false
            fi
        else
            _log warn "${C_YEL}[Required Code Owner Approval] rule is disabled!${C_END}"
        fi

        _log "${C_WHT}Required Code Review Approval:${C_END} ${is_required_code_review_approval}"
        _log "${C_WHT}Required Code Owner Approval:${C_END} ${is_required_code_owner_approval}"
    else
        _log warn "${C_YEL}No rules found for repository!${C_END}"
    fi

    echo "QUALITY_GATE__CODE_REVIEW_APPROVAL=$is_required_code_review_approval" >>"$GITHUB_ENV"
    echo "QUALITY_GATE__CODE_REVIEW_OWNER_APPROVAL=$is_required_code_owner_approval" >>"$GITHUB_ENV"
}
