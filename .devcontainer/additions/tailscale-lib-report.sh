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

# Display network trace information
display_trace_info() {
    local trace_json="$1"
    local description="$2"

    log_info "${description:-Network trace information}:"

    echo "$trace_json" | jq -r '
        "Target: \(.target)",
        "Hops: \(.hops | length)",
        "Path:",
        (.hops[] | "  \(.hop). \(.host) (\(.ip)) \(.times | join("ms, "))ms")
    ' | while IFS= read -r line; do
        log_info "$line"
    done
}

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

# Display connection status
display_connection_status() {
    local status_json="$1"

    log_info "Connection Status:"
    log_info "=================="

    # Connection type
    local conn_type
    conn_type=$(echo "$status_json" | jq -r '
        if .Self.CurAddr != "" then "direct (\(.Self.CurAddr))"
        elif .Self.Relay != "" then "via relay (\(.Self.Relay))"
        else "unknown"
        end
    ')
    log_info "Connection Type: $conn_type"

    # DERP region
    local derp_region
    derp_region=$(echo "$status_json" | jq -r '.Self.Relay')
    if [[ -n "$derp_region" && "$derp_region" != "null" ]]; then
        log_info "DERP Region: $derp_region"
    fi

    # Peer connections
    local peer_count
    peer_count=$(echo "$status_json" | jq '.Peer | length')
    local online_peers
    online_peers=$(echo "$status_json" | jq '[.Peer[] | select(.Online == true)] | length')
    log_info "Peers: $online_peers online of $peer_count total"
}

# Generate health report
generate_health_report() {
    local status_json="$1"
    local network_state="$2"
    local output_file="${3:-${TAILSCALE_LOG_BASE}/health_report.txt}"

    log_info "Generating health report..."

    {
        echo "Tailscale Health Report"
        echo "======================="
        echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo

        # System Status
        echo "System Status:"
        echo "-------------"
        echo "Version: $(echo "$status_json" | jq -r '.Version')"
        echo "Backend State: $(echo "$status_json" | jq -r '.BackendState')"
        echo

        # Network Status
        echo "Network Status:"
        echo "--------------"
        local default_if
        default_if=$(echo "$network_state" | jq -r '.defaultInterface')
        echo "Default Interface: $default_if"
        echo "Routes:"
        echo "$network_state" | jq -r '.routing.routes[] | "  \(.dst // "default") via \(.gateway // "direct")"'
        echo

        # Health Issues
        echo "Health Issues:"
        echo "--------------"
        if echo "$status_json" | jq -e '.Health[] | select(.Severity != "none")' >/dev/null; then
            echo "$status_json" | jq -r '.Health[] | select(.Severity != "none") | "\(.Severity): \(.Message)"'
        else
            echo "No health issues detected"
        fi

    } > "$output_file"

    log_info "Health report saved to: ${output_file}"
    return 0
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
export -f display_trace_info display_configuration display_network_changes
export -f display_setup_progress display_connection_status
export -f generate_health_report generate_setup_report display_completion_summary
