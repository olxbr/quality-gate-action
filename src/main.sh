#!/bin/bash

source src/utils.sh
source src/github_client.sh

GH_TOKEN=${GITHUB_TOKEN}
REPOSITORY=${GITHUB_REPOSITORY}

_set_default_branch

_log "${C_WHT}Repository:${C_END} ${REPOSITORY}"
_log "${C_WHT}Default Branch:${C_END} ${DEFAULT_BRANCH}"

is_required_pull_request=false
is_required_code_review_approval=false
is_required_code_owner_approval=false

ruleset_ids=$(_get_ruleset_ids)
_log debug "${C_WHT}Ruleset IDs:${C_END} ${ruleset_ids}"

rules=$(_get_rules "$ruleset_ids")
_log debug "${C_WHT}Rules:${C_END} ${rules}"

if [[ $(jq 'length > 0' <<< "$rules") == true ]]; then
    is_required_pull_request=true
    is_required_code_review_approval=$(jq -r 'any(.[]; .required_approving_review_count > 0)' <<< "$rules")
    is_required_code_owner_approval=$(jq -r 'any(.[]; .require_code_owner_review == true)' <<< "$rules")
else
    _log warn "${C_YEL}No rules found for repository!${C_END}"
fi

_log "╔═════════════════════════════════════╗"
_log "║   ${C_WHT}Repository Configuration Checks${C_END}   ║"
_log "╚═════════════════════════════════════╝"
_log "┌─────────────────────────────────────┐"
_log "| Required Pull Request          | $(print_status $is_required_pull_request) |"
_log "| Required Code Review Approval  | $(print_status $is_required_code_review_approval) |"
_log "| Required Code Owner Approval   | $(print_status $is_required_code_owner_approval) |"
_log "└─────────────────────────────────────┘"
