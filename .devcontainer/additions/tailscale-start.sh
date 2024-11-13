#!/bin/bash
# File: .devcontainer/additions/tailscale-start.sh
#
# Purpose: Starts and configures Tailscale in a devcontainer
# Based on working example from howto documentation
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

# Install xdg-utils for clickable URLs
ensure_xdg_utils() {
    if ! command -v xdg-open >/dev/null; then
        log_info "Installing xdg-utils for clickable URLs..."
        apt-get update -qq && apt-get install -y xdg-utils >/dev/null 2>&1
    fi
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
    # Replace dots and special chars with hyphen and remove trailing hyphens
    username=$(echo "$username" | tr '.' '-' | tr -c '[:alnum:]-' '-' | sed 's/-*$//')

    # Construct hostname (without trailing hyphen)
    echo "devcontainer-${username}"
}

# Start Tailscale daemon
start_daemon() {
    log_info "Starting Tailscale daemon..."

    # Kill existing daemon if running
    if pidof tailscaled >/dev/null; then
        if [[ "$FORCE_RESTART" != "true" ]]; then
            log_error "Tailscale daemon is already running. Use --force to restart"
            return 1
        fi
        log_info "Stopping existing daemon..."
        pkill tailscaled || true
        sleep 2
    fi

    # Start daemon with verbose logging as shown in howto
    tailscaled --verbose=1 --statedir=/var/lib/tailscale &

    # Wait for daemon to start
    local retries=5
    while ((retries > 0)); do
        if pidof tailscaled >/dev/null; then
            log_info "Daemon started successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    log_error "Tailscale daemon failed to start"
    return 1
}

# Configure and start Tailscale
start_tailscale() {
    log_info "Starting Tailscale..."

    local hostname
    if ! hostname=$(generate_hostname); then
        return 1
    fi

    log_info "Starting Tailscale with hostname: ${hostname}"

    # Run tailscale up with hostname
    tailscale up --hostname="$hostname"

    # Check connection status after authentication
    if tailscale status | grep -q "^100\."; then
        log_info "Tailscale connected successfully"
        return 0
    else
        log_error "Failed to establish Tailscale connection"
        return 1
    fi
}

# Configure exit node
configure_exit_node() {
    if [[ "${TAILSCALE_EXIT_NODE_ENABLED}" != "true" ]]; then
        return 0
    fi

    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST}"
    log_info "Configuring exit node (${proxy_host})..."

    # Wait for proxy to be available
    local retries=10
    local exit_node_ip=""

    while ((retries > 0)); do
        exit_node_ip=$(tailscale status --json | jq -r --arg name "${proxy_host}" '
            .Peer | to_entries[] |
            select(.value.HostName == $name) |
            .value.TailscaleIPs[0]
        ')

        if [[ -n "${exit_node_ip}" && "${exit_node_ip}" != "null" ]]; then
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [[ -z "${exit_node_ip}" || "${exit_node_ip}" == "null" ]]; then
        log_error "Could not find exit node: ${proxy_host}"
        return 1
    fi

    log_info "Setting up exit node with IP: ${exit_node_ip}"
    # Set exit node with correct flag syntax
    if ! tailscale set \
        --exit-node="${exit_node_ip}" \
        --exit-node-allow-lan-access=true; then
        log_error "Failed to configure exit node"
        return 1
    fi

    log_info "Exit node configured successfully"
    # Display final status
    tailscale status
}

# Main startup process
main() {
    # Ensure xdg-utils is installed first
    ensure_xdg_utils

    start_daemon || exit 1
    start_tailscale || exit 1
    configure_exit_node || exit 1

    log_info "Tailscale startup completed successfully"
    tailscale status
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
