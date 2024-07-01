#!/bin/bash

# shellcheck disable=SC1091
source "${ACTION_PATH}"/src/utils.sh
source "${ACTION_PATH}"/src/github_client.sh

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
        _log "Checking Owner Approval..."

        is_codeowners_file_exists=$(_validate_codeowners)
        is_required_code_owner_review=$(jq -sr 'any(.[]; .require_code_owner_review == true)' <<<"$rules")

        if [[ $is_codeowners_file_exists == false ]]; then
            _log warn "CODEOWNERS file not found!"
            _insert_warning_message required_owner_approval_warn_msg "⚠️ CODEOWNERS file not found!"
        fi

        if [[ $is_required_code_owner_review == true ]]; then
            if [[ $is_codeowners_file_exists == true ]]; then
                is_required_owner_approval=true
            fi
        else
            _log warn "[Require review from Code Owners] is unchecked!"
            _insert_warning_message required_owner_approval_warn_msg "⚠️ **Require review from Code Owners** is unchecked!"
        fi

        _log "Required Owner Approval:${C_END} ${is_required_owner_approval}"
        _log "CODEOWNERS file exists:${C_END} $is_codeowners_file_exists"

    else
        _log warn "Owner Approval check skipped!"
        _insert_warning_message required_owner_approval_warn_msg "Owner Approval check skipped!"
        is_required_owner_approval=true
    fi

    {
        echo "QUALITY_GATE__OWNER_APPROVAL_PASS=$is_required_owner_approval"
        echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=$required_owner_approval_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check code review
function _check_code_review() {
    local is_required_code_review=false
    local required_code_review_warn_msg=""

    if [[ $skip_code_review == false ]]; then
        _log "Checking Code Review..."

        is_required_code_review=$(jq -sr 'any(.[]; .required_approving_review_count > 0)' <<<"$rules")
        if [[ $is_required_code_review == false ]]; then
            _log warn "[Required approvals] are less than 0!"
            _insert_warning_message required_code_review_warn_msg "⚠️ **Required approvals** are less than 0!"
        fi

        _log "Required Code Review:${C_END} ${is_required_code_review}"

    else
        _log warn "Code Review check skipped!"
        _insert_warning_message required_code_review_warn_msg "Code Review check skipped!"
        is_required_code_review=true
    fi

    {
        echo "QUALITY_GATE__CODE_REVIEW_PASS=$is_required_code_review"
        echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=$required_code_review_warn_msg"
    } >>"$GITHUB_ENV"
}

# Function to check vulnerabilites
function _check_vulnerability_configs() {
    local has_critical_alerts=false
    local vulnerability_pass=true
    local vulnerability_warn_msg=""
    local vulnerability_alert_details=""
    local vulnerability_total_count=0
    local total_dependabot_alerts=0
    local total_code_scanning_alerts=0
    local total_secret_scanning_alerts=0

    if [[ $skip_vulnerability == false ]]; then
        _log "Checking Vulnerability Configurations..."

        is_dependabot_alerts_disabled=$(_is_dependabot_alerts_disabled)

        if [[ $is_dependabot_alerts_disabled == true ]]; then
            _log warn "Dependabot alerts is disabled!"
            _insert_warning_message vulnerability_warn_msg "⚠️ Dependabot alerts is disabled!"
            vulnerability_pass=false
        fi

        is_github_advanced_security_disabled=$(_is_github_advanced_security_disabled)
        is_secret_scanning_disabled=true

        if [[ $is_github_advanced_security_disabled == true ]]; then
            _log warn "GitHub Advanced Security is disabled!"
            _insert_warning_message vulnerability_warn_msg "⚠️ GitHub Advanced Security is disabled!"
            vulnerability_pass=false
        else
            is_secret_scanning_disabled=$(_is_secret_scanning_disabled)
        fi

        if [[ $is_secret_scanning_disabled == true ]]; then
            _log warn "Secret scanning is disabled!"
            _insert_warning_message vulnerability_warn_msg "⚠️ Secret scanning is disabled!"
            vulnerability_pass=false
        fi

        _log "Checking Vulnerability Alerts..."

        if [[ $is_dependabot_alerts_disabled == false ]]; then
            dependabot_alerts=$(_get_dependabot_alerts_count_by_severity)
            _log debug "[Dependabot Alerts] Result:${C_END} $dependabot_alerts"

            if [[ -n $dependabot_alerts ]]; then
                total_dependabot_alerts=$(jq -r '[.[].count] | add' <<<"$dependabot_alerts")
                dependabot_alerts_content=$(jq -r 'map("\(.severity) `\(.count)`") | join(", ")' <<<"$dependabot_alerts")
                has_critical_alerts=$(jq -r 'any(.[]; .severity == "critical")' <<<"$dependabot_alerts")
                vulnerability_total_count=$((vulnerability_total_count + total_dependabot_alerts))

                _log "[Dependabot Alerts] Total:${C_END} $total_dependabot_alerts"
                _log "[Dependabot Alerts] Content:${C_END} $dependabot_alerts_content"
                vulnerability_alert_details+="<li>**Dependabot Alerts:** $dependabot_alerts_content</li>"
            fi
        fi

        if [[ $is_github_advanced_security_disabled == false ]]; then
            code_scanning_alerts=$(_get_code_scanning_alerts_count_by_severity)
            _log debug "[Code Scanning Alerts] Result:${C_END} $code_scanning_alerts"

            if [[ -n $code_scanning_alerts ]]; then
                total_code_scanning_alerts=$(jq -r '[.[].count] | add' <<<"$code_scanning_alerts")
                code_scanning_alerts_content=$(jq -r 'map("\(.severity) `\(.count)`") | join(", ")' <<<"$code_scanning_alerts")
                has_critical_alerts=$(jq -r 'any(.[]; .severity == "critical")' <<<"$code_scanning_alerts")
                vulnerability_total_count=$((vulnerability_total_count + total_code_scanning_alerts))

                _log "[Code Scanning Alerts] Total:${C_END} $total_code_scanning_alerts"
                _log "[Code Scanning Alerts] Content:${C_END} $code_scanning_alerts_content"
                vulnerability_alert_details+="<li>**Code Scanning Alerts:** $code_scanning_alerts_content</li>"
            fi
        fi

        if [[ $is_secret_scanning_disabled == false ]]; then
            secret_scanning_alerts=$(_get_secret_scanning_alerts_count)
            _log debug "[Secret Scanning Alerts] Result:${C_END} $secret_scanning_alerts"

            if [[ -n $secret_scanning_alerts ]]; then
                total_secret_scanning_alerts=$secret_scanning_alerts
                secret_scanning_alerts_content="\`$secret_scanning_alerts\`"
                has_critical_alerts=true
                vulnerability_total_count=$((vulnerability_total_count + secret_scanning_alerts))

                _log "[Secret Scanning Alerts] Total:${C_END} $total_secret_scanning_alerts"
                _log "[Secret Scanning Alerts] Content:${C_END} $secret_scanning_alerts_content"
                vulnerability_alert_details+="<li>**Secret Scanning Alerts (critical):** $secret_scanning_alerts_content</li>"
            fi
        fi

    else
        _log warn "Vulnerability check skipped!"
        _insert_warning_message vulnerability_warn_msg "Vulnerability check skipped!"
    fi

    if [[ -n $vulnerability_alert_details ]]; then
        if [[ $has_critical_alerts == true ]]; then
            _log warn "Critical alerts found, resolve them to proceed!"
            _insert_warning_message vulnerability_warn_msg "⚠️ Critical alerts found, resolve them to proceed!"
            vulnerability_pass=false
        fi

        _log "Vulnerability Total Count:${C_END} $vulnerability_total_count"
        msg="⚠️ Security \`$vulnerability_total_count\`<details><summary>Details</summary><ul>$vulnerability_alert_details</ul></details>"
        vulnerability_warn_msg+="<br>$msg"
    fi

    {
        echo "QUALITY_GATE__VULNERABILITY_PASS=$vulnerability_pass"
        echo "QUALITY_GATE__VULNERABILITY_WARN_MSGS=$vulnerability_warn_msg"
        echo "QUALITY_GATE__VULNERABILITY_DEPENDABOT_ALERTS=$total_dependabot_alerts"
        echo "QUALITY_GATE__VULNERABILITY_CODE_SCANNING_ALERTS=$total_code_scanning_alerts"
        echo "QUALITY_GATE__VULNERABILITY_SECRET_SCANNING_ALERTS=$total_secret_scanning_alerts"
    } >>"$GITHUB_ENV"
}

# Function to check repo configs
function _check_repo_configs() {
    skip_owner_approval=$(_has_gate_to_skip "owner_approval")
    skip_code_review=$(_has_gate_to_skip "code_review")
    skip_vulnerability=$(_has_gate_to_skip "vulnerability")

    echo "QUALITY_GATE__VULNERABILITY_SKIPPED=$skip_vulnerability" >>"$GITHUB_ENV"

    if [[ $skip_owner_approval == false || $skip_code_review == false || $skip_vulnerability == false ]]; then
        _log "Checking Repository Configurations..."
        _log "Repository:${C_END} ${REPOSITORY}"
        _log "Default Branch:${C_END} ${GITHUB_DEFAULT_BRANCH}"
        _log "Pull Request Number:${C_END} ${PR_NUMBER}"
        _log "Pull Request Head SHA:${C_END} ${PR_HEAD_SHA}"

        ruleset_ids=$(_get_ruleset_ids)
        rules=$(_get_rules "$ruleset_ids")

        if [[ $(jq -s 'length > 0' <<<"$rules") == true ]]; then
            _check_owner_approval
            _check_code_review
        else
            message="No rules found for repository!"
            _log warn "${message}"
            {
                echo "QUALITY_GATE__CODE_REVIEW_PASS=false"
                echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=⚠️ $message"
                echo "QUALITY_GATE__OWNER_APPROVAL_PASS=false"
                echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=⚠️ $message"
            } >>"$GITHUB_ENV"
        fi

        _check_vulnerability_configs

    else
        _log warn "Repository Configurations check skipped!"
        {
            echo "QUALITY_GATE__CODE_REVIEW_PASS=true"
            echo "QUALITY_GATE__CODE_REVIEW_WARN_MSGS=Code Review check skipped!"
            echo "QUALITY_GATE__OWNER_APPROVAL_PASS=true"
            echo "QUALITY_GATE__OWNER_APPROVAL_WARN_MSGS=Owner Approval check skipped!"
            echo "QUALITY_GATE__VULNERABILITY_PASS=true"
            echo "QUALITY_GATE__VULNERABILITY_WARN_MSGS=Vulnerability check skipped!"
        } >>"$GITHUB_ENV"
    fi
}
