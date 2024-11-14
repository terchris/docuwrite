#!/bin/bash
# File: .devcontainer/additions/tailscale-lib-exitnode.sh
#
# Purpose:
#   Manages Tailscale exit node configuration, verification, and monitoring.
#   Handles setup, verification, and routing checks for exit nodes.
#
# Dependencies:
#   - tailscale-lib-common.sh : Common utilities and logging
#   - tailscale-lib-status.sh : Status management
#   - tailscale-lib-network.sh : Network verification
#   - jq : JSON processing
#
# Author: Terje Christensen
# Created: November 2024

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly"
    exit 1
fi

# Configuration with defaults
SETUP_RETRY_COUNT="${SETUP_RETRY_COUNT:-3}"
SETUP_RETRY_DELAY="${SETUP_RETRY_DELAY:-2}"

# Find and make sure we can reach the exit node
find_exit_node() {
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"
    local max_retries=3
    local retry_delay=5
    local attempt=1

    log_info "Looking for exit node: ${proxy_host}"

    local exit_node_info
    exit_node_info=$(get_valid_exit_node "$proxy_host") || return 1

    local exit_node_ip
    exit_node_ip=$(echo "$exit_node_info" | jq -r '.ip')

    while ((attempt <= max_retries)); do
        log_info "Attempt $attempt/$max_retries: Verifying connectivity to exit node..."

        if check_basic_connectivity "$exit_node_ip" 5 1; then
            log_info "Successfully verified connectivity to exit node"
            echo "$exit_node_info"
            return 0
        fi

        attempt=$((attempt + 1))
        if ((attempt <= max_retries)); then
            log_info "Waiting ${retry_delay}s before retry..."
            sleep "$retry_delay"

            # Re-verify exit node status
            exit_node_info=$(get_valid_exit_node "$proxy_host") || return 1
        fi
    done

    log_error "Could not establish reliable connection to exit node after $max_retries attempts"
    log_info "Troubleshooting steps:"
    log_info "1. Check if exit node '${proxy_host}' is running and accessible"
    log_info "2. Verify network connectivity between container and exit node"
    log_info "3. Check Tailscale status on exit node: tailscale status"
    return "$EXIT_EXITNODE_ERROR"
}

get_valid_exit_node() {
    local proxy_host="$1"
    local status_json

    if ! status_json=$(get_tailscale_status true); then
        log_error "Failed to get Tailscale status"
        return 1
    fi

    local exit_node_info
    exit_node_info=$(echo "$status_json" | jq -r --arg name "$proxy_host" '
        .Peer | to_entries[] |
        select(.value.HostName == $name and .value.ExitNodeOption == true) |
        {
            id: .key,
            hostname: .value.HostName,
            ip: .value.TailscaleIPs[0],
            online: .value.Online,
            connection: .value.CurAddr,
            exitNode: .value.ExitNode,
            exitNodeOption: .value.ExitNodeOption
        }
    ')

    if [[ -z "$exit_node_info" || "$exit_node_info" == "null" ]]; then
        log_error "No suitable exit node found with name: ${proxy_host}"
        show_available_exit_nodes "$status_json"
        return 1
    fi

    if [[ "$(echo "$exit_node_info" | jq -r '.online')" != "true" ]]; then
        log_error "Exit node '${proxy_host}' exists but is offline"
        return 1
    fi

    echo "$exit_node_info"
    return 0
}

show_available_exit_nodes() {
    local status_json="$1"

    log_info "Available exit nodes:"
    echo "$status_json" | jq -r '
        .Peer | to_entries[] |
        select(.value.ExitNodeOption == true) |
        "  \(.value.HostName):\n    IP: \(.value.TailscaleIPs[0])\n    Online: \(.value.Online)\n    Connection: \(.value.CurAddr // "relay")"
    '
}

# Configure exit node
setup_exit_node() {
    local exit_node_info="$1"
    local allow_lan="${TAILSCALE_EXIT_NODE_ALLOW_LAN:-true}"
    local retry_count=0

    local proxy_host
    proxy_host=$(echo "$exit_node_info" | jq -r '.hostname')
    local exit_node_ip
    exit_node_ip=$(echo "$exit_node_info" | jq -r '.ip')

    log_info "Configuring exit node '${proxy_host}' (${exit_node_ip})..."

    # Prepare configuration options
    local config_options=(
        "--reset"
        "--exit-node=$exit_node_ip"
        "--exit-node-allow-lan-access=$allow_lan"
    )

    # Configure exit node with retries
    while ((retry_count < SETUP_RETRY_COUNT)); do
        log_info "Configuring exit node (attempt $((retry_count + 1))/${SETUP_RETRY_COUNT})..."

        if ! tailscale up "${config_options[@]}"; then
            retry_count=$((retry_count + 1))
            if ((retry_count < SETUP_RETRY_COUNT)); then
                log_warn "Exit node configuration failed, retrying in ${SETUP_RETRY_DELAY} seconds..."
                sleep "$SETUP_RETRY_DELAY"
                continue
            fi
            log_error "Failed to configure exit node after ${SETUP_RETRY_COUNT} attempts"
            return "$EXIT_EXITNODE_ERROR"
        fi

        # Wait for configuration to apply
        log_info "Waiting for exit node configuration to apply..."
        local verification_attempts=10
        local verification_count=0
        while ((verification_count < verification_attempts)); do
            # Get current status
            local status_json
            status_json=$(get_tailscale_status true)

            # Check if exit node is configured
            if echo "$status_json" | jq -e --arg ip "$exit_node_ip" \
                '.ExitNodeStatus.TailscaleIPs[] | select(. | startswith($ip))' >/dev/null; then
                log_info "Exit node success. Traffic will now go through '${proxy_host}' (${exit_node_ip})"
                return 0
            fi

            # If not configured yet, wait and retry
            verification_count=$((verification_count + 1))
            if ((verification_count < verification_attempts)); then
                log_debug "Waiting for exit node configuration... ($verification_count/$verification_attempts)"
                sleep 2
            fi
        done

        # If verification failed, retry complete setup
        retry_count=$((retry_count + 1))
        if ((retry_count < SETUP_RETRY_COUNT)); then
            log_warn "Exit node verification failed, retrying complete setup..."
            sleep "$SETUP_RETRY_DELAY"
            continue
        fi
    done

    log_error "Failed to verify exit node configuration"
    return "$EXIT_EXITNODE_ERROR"
}

# Verify routing through exit node
verify_exit_routing() {
    local exit_node_info="$1"
    local test_url="${TAILSCALE_TEST_URL:-www.sol.no}"

    local proxy_host
    proxy_host=$(echo "$exit_node_info" | jq -r '.hostname')
    local exit_node_ip
    exit_node_ip=$(echo "$exit_node_info" | jq -r '.ip')

    log_info "Verifying routing through exit node '${proxy_host}'..."

    if ! verify_network_state basic; then
        log_error "Basic network verification failed"
        return "$EXIT_NETWORK_ERROR"
    fi

    # Get the first hop IP from traceroute
    local trace_info
    trace_info=$(trace_route "$test_url")

    local first_hop
    first_hop=$(echo "$trace_info" | jq -r '.hops[0].probes[0].ip')

    if [[ "$first_hop" != "$exit_node_ip" ]]; then
        log_error "Traffic not routing through exit node"
        log_error "Expected first hop: ${exit_node_ip}"
        log_error "Actual first hop: ${first_hop:-null}"
        return "$EXIT_EXITNODE_ERROR"
    fi

    return 0
}


# Export required functions
export -f find_exit_node setup_exit_node
export -f verify_exit_routing
