#!/bin/bash
# File: .devcontainer/additions/tailscale-start.sh
#
# Purpose: Starts and configures Tailscale in a devcontainer with proper sequencing
#
# Usage: sudo .devcontainer/additions/tailscale-start.sh [--force]
#
# Options:
#   --force    Force restart if already running

set -euo pipefail

# Load environment variables
if [[ -f "/workspace/.devcontainer.extend/tailscale.env" ]]; then
    # shellcheck source=/dev/null
    source "/workspace/.devcontainer.extend/tailscale.env"
else
    echo "Error: tailscale.env not found in .devcontainer.extend/"
    exit 1
fi

# Logging functions
log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_debug() { [[ "${TAILSCALE_LOG_TO_CONSOLE:-false}" == "true" ]] && echo "[DEBUG] $*" >&2; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Parse arguments
FORCE_RESTART=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_RESTART=true
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Basic network test function
test_connectivity() {
    local target="$1"
    local description="$2"
    local count="${3:-4}"
    local timeout="${4:-5}"

    log_info "Testing connectivity to ${description} (${target})..."

    if ! ping -c "$count" -W "$timeout" "$target" >/dev/null 2>&1; then
        log_error "Cannot reach ${description} at ${target}"
        return 1
    fi

    log_info "Successfully reached ${description}"
    return 0
}

# Check internet connectivity
check_internet() {
    local dns_servers=(
        "8.8.8.8"      # Google DNS
        "1.1.1.1"      # Cloudflare DNS
        "208.67.222.222" # OpenDNS
    )

    log_info "Checking internet connectivity using DNS servers..."

    for dns in "${dns_servers[@]}"; do
        if test_connectivity "$dns" "DNS server" 1 2; then
            return 0
        fi
    done

    log_error "No internet connectivity detected. Please check your network connection"
    return 1
}

# Generate hostname from email
generate_hostname() {
    local email="${TAILSCALE_USER_EMAIL}"
    if [[ -z "$email" ]]; then
        log_error "TAILSCALE_USER_EMAIL must be set in tailscale.env"
        return 1
    fi

    # Extract username part from email and clean it
    local username="${email%@*}"
    # Replace dots and special chars with hyphen
    username=$(echo "$username" | tr '.' '-' | tr -c '[:alnum:]-' '-' | sed 's/-*$//')

    echo "devcontainer-${username}"
}

# Start Tailscale daemon
start_daemon() {
    log_info "Checking Tailscale daemon status..."

    if pidof tailscaled >/dev/null; then
        if [[ "$FORCE_RESTART" != "true" ]]; then
            log_error "Tailscale daemon is already running. Use --force to restart"
            return 1
        fi
        log_info "Stopping existing Tailscale daemon..."
        pkill tailscaled || true
        sleep 2
    fi

    log_info "Starting Tailscale daemon..."
    # Redirect verbose output to log file
    tailscaled --verbose=1 --statedir="${TAILSCALE_STATE_DIR}" > "${TAILSCALE_DAEMON_LOG}" 2>&1 &

    local retries=5
    while ((retries > 0)); do
        if pidof tailscaled >/dev/null; then
            log_info "Daemon started successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    log_error "Failed to start Tailscale daemon"
    return 1
}


# Initial Tailscale connection
connect_tailscale() {
    local hostname
    hostname=$(generate_hostname)

    log_info "Connecting to Tailscale network with hostname: ${hostname}"
    tailscale up --hostname="$hostname"

    # Wait for connection and network to be established
    local retries=15  # Increased retries
    while ((retries > 0)); do
        if tailscale status >/dev/null 2>&1; then
            local ip
            ip=$(tailscale ip)
            log_info "Successfully connected to Tailscale network with IP: ${ip}"

            # Wait for network to stabilize
            log_info "Waiting for network to stabilize..."
            sleep 5

            # Verify network is ready by checking status
            if tailscale status | grep -q "^100\."; then
                return 0
            fi
        fi
        retries=$((retries - 1))
        [[ $retries -gt 0 ]] && log_info "Waiting for Tailscale connection... (${retries} attempts remaining)"
        sleep 2
    done

    log_error "Failed to establish Tailscale connection"
    return 1
}


# Find and verify exit node
find_exit_node() {
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"
    log_info "Looking for exit node: ${proxy_host}"

    # Check if the node exists and has ExitNodeOption=true in status
    local exit_node_ip
    exit_node_ip=$(tailscale status --json | jq -r --arg name "$proxy_host" '
        .Peer | to_entries[] |
        select(.value.HostName == $name and .value.ExitNodeOption == true) |
        .value.TailscaleIPs[0]
    ')

    if [[ -z "$exit_node_ip" || "$exit_node_ip" == "null" ]]; then
        log_error "No suitable exit node found with name: ${proxy_host}"

        # Show available exit nodes
        log_info "Available exit nodes:"
        tailscale status --json | jq -r '
            .Peer | to_entries[] |
            select(.value.ExitNodeOption == true) |
            "  \(.value.HostName): \(.value.TailscaleIPs[0]) (Online: \(.value.Online))"
        '
        return 1
    fi

    # Verify the node is online
    local is_online
    is_online=$(tailscale status --json | jq -r --arg name "$proxy_host" '
        .Peer | to_entries[] |
        select(.value.HostName == $name) |
        .value.Online
    ')

    if [[ "$is_online" != "true" ]]; then
        log_error "Exit node '${proxy_host}' exists but is offline"
        return 1
    fi

    log_info "Found exit node '${proxy_host}' with IP: ${exit_node_ip} (Online)"
    echo "$exit_node_ip"
    return 0
}


# Verify network readiness and get status
verify_network_readiness() {
    log_info "Verifying network readiness..."

    local status_json
    status_json=$(tailscale status --json)

    # Check if we're actually connected
    if ! echo "$status_json" | jq -e '.BackendState == "Running"' >/dev/null; then
        log_error "Tailscale backend is not running"
        return 1
    fi  # Changed '}' to 'fi'

    # Check if we have valid IPs
    if ! echo "$status_json" | jq -e '.TailscaleIPs | length > 0' >/dev/null; then
        log_error "No Tailscale IPs assigned"
        return 1
    fi

    # Get interesting network information
    local derp_region
    derp_region=$(echo "$status_json" | jq -r '.Self.Relay')

    local connection_type
    connection_type=$(echo "$status_json" | jq -r '
        .Peer | to_entries[] |
        select(.value.Active == true) |
        .value.CurAddr |
        if . == "" then "relay" else "direct" end
    ')

    local online_peers
    online_peers=$(echo "$status_json" | jq -r '[.Peer[] | select(.Online == true) | .HostName] | length')

    local total_peers
    total_peers=$(echo "$status_json" | jq -r '.Peer | length')

    local dns_suffix
    dns_suffix=$(echo "$status_json" | jq -r '.MagicDNSSuffix')

    # Display interesting information
    log_info "Network Information:"
    log_info "- DERP Region: ${derp_region:-unknown}"
    log_info "- Connection Type: ${connection_type:-unknown}"
    log_info "- Online Peers: ${online_peers}/${total_peers}"
    log_info "- Magic DNS Suffix: ${dns_suffix}"

    # Get connection health
    local health_issues
    health_issues=$(echo "$status_json" | jq -r '.Health[] | select(.Severity != "none") | .Message' 2>/dev/null)
    if [[ -n "$health_issues" ]]; then
        log_warn "Health Issues Detected:"
        while IFS= read -r issue; do
            log_warn "- ${issue}"
        done <<< "$health_issues"
    else
        log_info "No health issues detected"
    fi

    return 0
}

# Test connectivity to exit node
verify_exit_node() {
    local exit_node_ip="$1"
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"

    log_info "Verifying connectivity to exit node '${proxy_host}' (${exit_node_ip})..."

    # Verify network readiness
    verify_network_readiness || return 1

    # Now test connectivity
    log_info "Testing connectivity to exit node (${exit_node_ip})..."
    local ping_attempts=3
    local attempt=1

    while ((attempt <= ping_attempts)); do
        if ping -c 1 -W 5 "$exit_node_ip" >/dev/null 2>&1; then
            log_info "Successfully verified connectivity to exit node"
            return 0
        fi
        log_info "Ping attempt ${attempt} failed, retrying..."
        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "Cannot reach exit node at ${exit_node_ip}"
    return 1
}


# Configure exit node
configure_exit_node() {
    local exit_node_ip="$1"
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"
    local hostname
    hostname=$(generate_hostname)

    if [[ -z "$exit_node_ip" ]]; then
        log_error "No exit node IP provided for configuration"
        return 1
    fi

    log_info "Configuring '${proxy_host}' as exit node (${exit_node_ip})..."

    # Use environment variable for LAN access setting
    local lan_access="${TAILSCALE_EXIT_NODE_ALLOW_LAN:-true}"

    # Configure exit node with --reset to handle existing settings
    if ! tailscale up \
        --reset \
        --hostname="$hostname" \
        --exit-node="$exit_node_ip" \
        --exit-node-allow-lan-access="$lan_access"; then
        log_error "Failed to configure '${proxy_host}' as exit node"
        return 1
    fi

    # Wait for configuration to apply
    log_info "Waiting for exit node configuration to apply..."
    local retries=10
    while ((retries > 0)); do
        # Get current status
        local status_json
        status_json=$(tailscale status --json)

        # Check ExitNodeStatus instead of ExitNode
        if jq -e --arg ip "$exit_node_ip" '.ExitNodeStatus.TailscaleIPs[] | select(. | startswith($ip))' <<< "$status_json" >/dev/null; then
            log_info "Exit node configuration successfully applied"
            return 0
        fi

        # If not configured yet, wait and retry
        retries=$((retries - 1))
        if ((retries > 0)); then
            log_info "Waiting for exit node configuration... (${retries} attempts remaining)"
            sleep 2
        fi
    done

    if ((retries == 0)); then
        log_error "Timed out waiting for exit node configuration"

        # Check if routes are set up despite status not showing
        if ip route | grep -q "default.*via.*$exit_node_ip"; then
            log_info "Exit node routes appear to be configured correctly despite status mismatch"
            return 0
        fi

        log_error "Exit node configuration failed to apply"
        return 1
    fi

    return 0
}

# Check routing path
check_routing_path() {
    local target="$1"
    local max_hops="${2:-5}"  # Default to 5 hops
    local timeout="${3:-2}"   # Default 2 second timeout

    if ! command -v traceroute >/dev/null; then
        log_info "Traceroute not available, skipping path check"
        return 0
    fi

    log_info "Checking routing path to ${target} (max ${max_hops} hops)..."

    local route_output
    route_output=$(traceroute -m "$max_hops" -w "$timeout" "$target" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to trace route to ${target}"
        return 1
    fi

    # Get first hop
    local first_hop
    first_hop=$(echo "$route_output" | head -n 2 | tail -n 1)
    log_info "First hop: ${first_hop}"

    # Check if first hop is our exit node
    if [[ "$first_hop" =~ ${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy} ]]; then
        log_info "Verified traffic is routing through exit node"
        return 0
    else
        log_error "Traffic not routing through exit node"
        return 1
    fi
}

# Verify routing through exit node
verify_routing() {
    local test_url="${TAILSCALE_TEST_URL:-www.sol.no}"
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"

    log_info "Verifying internet routing through exit node '${proxy_host}'"
    log_info "Testing connectivity to: ${test_url}"

    # Test basic connectivity first
    if ! test_connectivity "$test_url" "test URL" 4 5; then
        return 1
    fi

    # Check routing path
    if ! check_routing_path "$test_url" 5 2; then
        log_error "Failed to verify routing path through exit node"
        return 1
    fi

    log_info "Successfully verified routing through exit node '${proxy_host}'"
    return 0
}


# Get network summary
show_network_summary() {
    log_info "Tailscale Network Summary:"
    log_info "=========================="

    # Get status in JSON format for parsing
    local status_json
    status_json=$(tailscale status --json)

    # Get self information
    local my_hostname
    my_hostname=$(echo "$status_json" | jq -r '.Self.HostName')
    local my_ip
    my_ip=$(echo "$status_json" | jq -r '.Self.TailscaleIPs[0]')

    # Get proxy information
    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST:-devcontainerproxy}"
    local proxy_ip
    proxy_ip=$(echo "$status_json" | jq -r --arg name "$proxy_host" '
        .Peer | to_entries[] |
        select(.value.HostName == $name) |
        .value.TailscaleIPs[0]
    ')

    # Test routing
    local test_url="${TAILSCALE_TEST_URL:-www.sol.no}"
    local hop_count
    hop_count=$(traceroute -m 10 -w 2 "$test_url" 2>/dev/null | wc -l)
    if [[ $hop_count -gt 0 ]]; then
        # Subtract 1 for the header line in traceroute output
        hop_count=$((hop_count - 1))
    fi

    # Output summary
    log_info "DevContainer Hostname: ${my_hostname}"
    log_info "DevContainer IP: ${my_ip}"
    log_info "DevContainerProxy: ${proxy_host}"
    log_info "DevContainerProxy IP: ${proxy_ip}"
    log_info "Routing via ${proxy_host} to ${test_url} hops: ${hop_count}"

    # Check if hostname has a number suffix
    if [[ "$my_hostname" =~ -[0-9]+$ ]]; then
        log_warn "Note: Your hostname has a numeric suffix. This means duplicate hostnames exist in your tailnet."
    fi
}

# Main startup process
main() {
    log_info "Starting Tailscale setup process..."

    # Check internet connectivity first
    check_internet || exit 1

    # Start daemon
    start_daemon || exit 1

    # Connect to Tailscale
    connect_tailscale || exit 1

    # Find exit node
    local exit_node_ip
    exit_node_ip=$(find_exit_node) || exit 1

    # Verify exit node connectivity
    verify_exit_node "$exit_node_ip" || exit 1

    # Configure exit node
    configure_exit_node "$exit_node_ip" || exit 1

    # Final verification
    verify_routing || exit 1

    log_info "Tailscale setup completed successfully"
    show_network_summary
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
