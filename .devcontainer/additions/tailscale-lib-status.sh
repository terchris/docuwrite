#!/bin/bash
# File: .devcontainer/additions/tailscale-lib-status.sh
#
# Purpose:
#   Manages Tailscale status information, including status caching,
#   parsing, and validation. Provides centralized status management
#   to reduce redundant status calls.
#
# Dependencies:
#   - tailscale-lib-common.sh : Common utilities and logging
#   - jq : JSON processing
#
# Author: Terje Christensen
# Created: November 2024

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly"
    exit 1
fi

# containers hostname will have this prefix
readonly DEVCONTAINER_PREFIX="devcontainer"


# Status cache configuration
readonly STATUS_CACHE_FILE="/tmp/tailscale_status_cache.json"
readonly STATUS_CACHE_TTL=5  # Cache lifetime in seconds

# Initialize status tracking
declare -g LAST_STATUS_CHECK=0
declare -g CURRENT_STATUS=""

# Get Tailscale status (with caching)
get_tailscale_status() {
    local force_refresh="${1:-false}"
    local current_time
    current_time=$(date +%s)

    # Check if we should use cached status
    if [[ "$force_refresh" != "true" ]] &&
       [[ -n "$CURRENT_STATUS" ]] &&
       (( current_time - LAST_STATUS_CHECK <= STATUS_CACHE_TTL )); then
        echo "$CURRENT_STATUS"
        return 0
    fi

    # Get fresh status
    local status_output
    if ! status_output=$(tailscale status --json 2>&1); then
        # Check if the error message indicates tailscaled is not running
        if [[ "$status_output" == *"failed to connect to local tailscaled"* ]]; then
            log_error "Tailscaled is not running. Try: sudo systemctl start tailscaled"
            return 2
        fi
        log_error "Failed to get Tailscale status: $status_output"
        return 1
    fi

    # Validate that the output is valid JSON
    if ! echo "$status_output" | jq '.' >/dev/null 2>&1; then
        log_error "Invalid JSON output from tailscale status"
        return 1
    fi

    # Update cache
    CURRENT_STATUS="$status_output"
    LAST_STATUS_CHECK="$current_time"
    echo "$status_output"
    return 0
}

# Parse status for specific information
parse_status_field() {
    local status_json="$1"
    local field="$2"
    local default="${3:-}"

    local value
    value=$(echo "$status_json" | jq -r "$field")

    if [[ "$value" == "null" || -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            echo "$default"
            return 0
        fi
        return 1
    fi

    echo "$value"
    return 0
}

# Check if Tailscale is running
check_tailscale_running() {
    local status_json
    status_json=$(get_tailscale_status true)  # Force refresh

    if [[ -z "$status_json" ]]; then
        return 1
    fi

    local backend_state
    backend_state=$(parse_status_field "$status_json" '.BackendState')

    if [[ "$backend_state" != "Running" ]]; then
        return 1
    fi

    return 0
}

# Get current Tailscale IPs
get_tailscale_ips() {
    local status_json
    status_json=$(get_tailscale_status)

    local ips
    ips=$(parse_status_field "$status_json" '.Self.TailscaleIPs[]')

    if [[ -z "$ips" ]]; then
        return 1
    fi

    echo "$ips"
    return 0
}

# Get detailed connection information
get_connection_info() {
    local status_json
    status_json=$(get_tailscale_status)

    # Extract connection details into structured format
    jq -n --argjson status "$status_json" '{
        self: {
            hostname: $status.Self.HostName,
            ips: $status.Self.TailscaleIPs,
            derpRegion: $status.Self.Relay,
            online: $status.Self.Online,
            exitNode: $status.Self.ExitNode
        },
        exitNode: (
            if $status.ExitNodeStatus != null then
            $status.ExitNodeStatus | {
                id: .ID,
                online: .Online,
                ips: .TailscaleIPs
            }
            else null end
        ),
        connectionType: (
            if $status.Self.Relay != "" then "relay"
            elif $status.Self.CurAddr != "" then "direct"
            else "unknown"
            end
        ),
        lastUpdate: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
}

# Validate Tailscale configuration
validate_tailscale_config() {
    local status_json
    status_json=$(get_tailscale_status true)  # Force refresh

    local issues=()

    # Check if we're running
    if ! check_tailscale_running; then
        issues+=("Tailscale is not running")
    fi

    # Check if we have IPs assigned
    if ! get_tailscale_ips >/dev/null; then
        issues+=("No Tailscale IPs assigned")
    fi

    # Check if hostname matches our expected pattern
    local hostname
    hostname=$(parse_status_field "$status_json" '.Self.HostName')
    local expected_hostname
    expected_hostname="$DEVCONTAINER_PREFIX-$(echo "${TAILSCALE_USER_EMAIL%@*}" | tr '.' '-')"

    if [[ "$hostname" != "$expected_hostname"* ]]; then
        issues+=("Unexpected hostname: $hostname (expected: $expected_hostname)")
    fi

    # Report any issues
    if ((${#issues[@]} > 0)); then
        log_error "Configuration validation failed:"
        for issue in "${issues[@]}"; do
            log_error "- $issue"
        done
        return 1
    fi

    return 0
}

# Get peer information
get_peer_info() {
    local peer_id="$1"
    local status_json
    status_json=$(get_tailscale_status)

    local peer_info
    peer_info=$(echo "$status_json" | jq --arg id "$peer_id" '.Peer[$id]')

    if [[ -z "$peer_info" || "$peer_info" == "null" ]]; then
        return 1
    fi

    echo "$peer_info"
    return 0
}

# Monitor Tailscale health
check_tailscale_health() {
    local status_json
    status_json=$(get_tailscale_status true)  # Force refresh

    local health_issues
    health_issues=$(echo "$status_json" | jq -r '.Health[] | select(.Severity != "none") | .Message')

    if [[ -n "$health_issues" ]]; then
        log_warn "Tailscale health issues detected:"
        while IFS= read -r issue; do
            log_warn "- $issue"
        done <<< "$health_issues"
        return 1
    fi

    return 0
}

# Generate status summary
generate_status_summary() {
    local status_json
    status_json=$(get_tailscale_status)

    # Create comprehensive summary
    jq -n --argjson status "$status_json" '{
        status: {
            version: $status.Version,
            backendState: $status.BackendState,
            online: $status.Self.Online
        },
        network: {
            ips: $status.TailscaleIPs,
            derpRegion: $status.Self.Relay,
            peers: {
                total: ($status.Peer | length),
                online: ($status.Peer | map(select(.Online == true)) | length)
            }
        },
        exitNode: (
            if $status.ExitNodeStatus != null then
            $status.ExitNodeStatus | {
                enabled: true,
                online: .Online,
                ips: .TailscaleIPs
            }
            else {
                enabled: false,
                online: false,
                ips: []
            }
            end
        ),
        health: ($status.Health | map(select(.Severity != "none")) | map({
            severity: .Severity,
            message: .Message
        })),
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
}


generate_unique_hostname() {
    # Extract username part from email and clean it
    local username="${TAILSCALE_USER_EMAIL%@*}"
    # Replace dots and special chars with hyphen
    username=$(echo "$username" | tr '.' '-' | tr -c '[:alnum:]-' '-' | sed 's/-*$//')

    local base_hostname="$DEVCONTAINER_PREFIX-$username"

    echo "$base_hostname"
    return 0
}

detect_connection_type() {
    local status_json
    status_json=$(get_tailscale_status)

    local conn_type
    conn_type=$(echo "$status_json" | jq -r '
        if .Self.CurAddr != "" then "direct"
        elif .Self.Relay != "" then "relay"
        else "unknown"
        end
    ')

    echo "$conn_type"
    if [[ "$conn_type" == "relay" ]]; then
        log_warn "Using relay connection"
    fi
    return 0
}


# Export required functions
export -f get_tailscale_status parse_status_field check_tailscale_running
export -f get_tailscale_ips get_connection_info validate_tailscale_config
export -f get_peer_info check_tailscale_health generate_status_summary
export -f generate_unique_hostname detect_connection_type
