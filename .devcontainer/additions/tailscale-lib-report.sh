#!/bin/bash
# File: .devcontainer/additions/tailscale-lib-report.sh
#
# Purpose:
#   Handles all reporting and display functions for Tailscale status,
#   configuration, and network state.
#
# Dependencies:
#   - tailscale-lib-common.sh : Common utilities and logging
#   - tailscale-lib-status.sh : Status management
#   - tailscale-lib-network.sh : Network information
#   - jq : JSON processing
#
# Author: Terje Christensen
# Created: November 2024
#

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly"
    exit 1
fi


# Display configuration summary
display_configuration() {
    local config_json="$1"

    log_info "Tailscale Configuration Summary:"
    log_info "==============================="

    # Container Identity
    log_info "Container Identity:"
    log_info "- Hostname: $(echo "$config_json" | jq -r '.containerIdentity.hostname')"
    log_info "- DNS Name: $(echo "$config_json" | jq -r '.containerIdentity.dnsName')"
    log_info "- Tailscale IP: $(echo "$config_json" | jq -r '.containerIdentity.tailscaleIP')"
    log_info "- DERP Region: $(echo "$config_json" | jq -r '.containerIdentity.derpRegion')"
    log_info "- Created: $(echo "$config_json" | jq -r '.containerIdentity.created')"
    log_info ""

    # Tailnet Information
    log_info "Tailnet Information:"
    log_info "- Name: $(echo "$config_json" | jq -r '.tailnet.name')"
    log_info "- DNS Suffix: $(echo "$config_json" | jq -r '.tailnet.magicDNSSuffix')"
    log_info "- MagicDNS: $(echo "$config_json" | jq -r '.tailnet.magicDNSEnabled')"
    log_info ""

    # User Information
    log_info "User Information:"
    log_info "- Login: $(echo "$config_json" | jq -r '.userInfo.loginName')"
    log_info "- Name: $(echo "$config_json" | jq -r '.userInfo.displayName')"
    log_info ""

    # Exit Node Status
    log_info "Exit Node Status:"
    if [[ "$(echo "$config_json" | jq -r '.exitNode != null')" == "true" ]]; then
        log_info "- Host: $(echo "$config_json" | jq -r '.exitNode.host')"
        log_info "- IP: $(echo "$config_json" | jq -r '.exitNode.ip')"
        log_info "- Connection: $(echo "$config_json" | jq -r '.exitNode.connection')"
        log_info "- Traffic: ↑$(echo "$config_json" | jq -r '.exitNode.traffic.tx')B ↓$(echo "$config_json" | jq -r '.exitNode.traffic.rx')B"
    else
        log_info "- No exit node configured"
    fi
    log_info ""

    # Capabilities
    log_info "Capabilities:"
    echo "$config_json" | jq -r '.capMap | keys[]' | while IFS= read -r cap; do
        log_info "- $cap"
    done
}

# Display network state changes
display_network_changes() {
    local initial_state="$1"
    local final_state="$2"

    log_info "Network State Changes:"
    log_info "====================="

    # Compare routing
    log_info "Routing Changes:"
    jq -n --argjson init "$initial_state" --argjson final "$final_state" '
        def compare_routes:
            ($final.routing - $init.routing) as $added |
            ($init.routing - $final.routing) as $removed |
            {added: $added, removed: $removed};
        compare_routes
    ' | jq -r '
        if .added | length > 0 then
            "Added routes:",
            (.added[] | "  + \(.dst) via \(.gateway // "direct")")
        else empty end,
        if .removed | length > 0 then
            "Removed routes:",
            (.removed[] | "  - \(.dst) via \(.gateway // "direct")")
        else empty end
    ' | while IFS= read -r line; do
        log_info "$line"
    done
}

# Display setup progress
display_setup_progress() {
    local phase="$1"
    local status="$2"
    local progress="$3"
    local total="${4:-100}"

    # Calculate percentage
    local percentage=$((progress * 100 / total))

    # Create progress bar
    local width=50
    local completed=$((width * progress / total))
    local remaining=$((width - completed))

    local progress_bar="["
    for ((i=0; i<completed; i++)); do progress_bar+="="; done
    if ((completed < width)); then progress_bar+=">"; fi
    for ((i=0; i<remaining-1; i++)); do progress_bar+=" "; done
    progress_bar+="]"

    log_info "Phase: $phase"
    log_info "Status: $status"
    log_info "$progress_bar $percentage%"
    log_info ""
}

# Generate setup report
generate_setup_report() {
    local config_json="$1"
    local output_file="${2:-${TAILSCALE_LOG_BASE}/setup_report.txt}"

    {
        echo "Tailscale Setup Report"
        echo "======================"
        echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""

        # Display configuration
        display_configuration "$config_json"

        # Add network state changes if available
        if echo "$config_json" | jq -e '.networkState' >/dev/null; then
            echo ""
            display_network_changes \
                "$(echo "$config_json" | jq '.networkState.initial')" \
                "$(echo "$config_json" | jq '.networkState.final')"
        fi

    } > "$output_file"

    log_info "Setup report saved to: ${output_file}"
    return 0
}

# Display completion summary
display_completion_summary() {
    local config_json="$1"
    local start_time="$2"
    local end_time="$3"

    # Calculate duration
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    log_info "===================================="
    log_info "Tailscale Setup Complete"
    log_info "===================================="
    log_info ""
    log_info "Setup Duration: ${minutes}m ${seconds}s"
    log_info ""

    # Show key information
    log_info "Container Configuration:"
    log_info "- Hostname: $(echo "$config_json" | jq -r '.containerIdentity.hostname')"
    log_info "- IP: $(echo "$config_json" | jq -r '.containerIdentity.tailscaleIP')"
    log_info "- Network: $(echo "$config_json" | jq -r '.tailnet.name')"
    log_info ""

    if [[ "$(echo "$config_json" | jq -r '.exitNode != null')" == "true" ]]; then
        log_info "Exit Node:"
        log_info "- Host: $(echo "$config_json" | jq -r '.exitNode.host')"
        log_info "- IP: $(echo "$config_json" | jq -r '.exitNode.ip')"
        log_info "- Connection: $(echo "$config_json" | jq -r '.exitNode.connection')"
    fi

    log_info ""
    log_info "Setup reports have been saved to:"
    log_info "- ${TAILSCALE_LOG_BASE}/setup_report.txt"
    log_info "- ${TAILSCALE_LOG_BASE}/health_report.txt"
    log_info ""
    log_info "===================================="
}

# Export required functions
export -f display_configuration display_network_changes
export -f display_setup_progress
export -f generate_setup_report display_completion_summary
