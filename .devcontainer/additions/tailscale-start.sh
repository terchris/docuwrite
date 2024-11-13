#!/bin/bash
# File: .devcontainer/additions/tailscale-start.sh
#
# Purpose: Starts and configures Tailscale in a devcontainer
#
# Usage: sudo bash tailscale-start.sh [--force]
#
# Options:
#   --force    Force restart if already running

set -euo pipefail

# Load environment variables
if [[ -f "/workspaces/.devcontainer.extended/tailscale.env" ]]; then
    # shellcheck source=/dev/null
    source "/workspaces/.devcontainer.extended/tailscale.env"
else
    echo "Error: tailscale.env not found in .devcontainer.extended/"
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

# Generate hostname from email
generate_hostname() {
    local email="${TAILSCALE_USER_EMAIL}"
    if [[ -z "$email" ]]; then
        log_error "TAILSCALE_USER_EMAIL must be set in tailscale.env"
        return 1
    }

    # Extract username part from email (everything before @)
    local username="${email%@*}"

    # Replace dots and any other special chars with hyphen
    username=$(echo "$username" | tr '.' '-' | tr -c '[:alnum:]-' '-')

    # Construct the hostname with required prefix
    local hostname="devcontainerlocal-${username}"

    # Ensure no double hyphens and remove trailing hyphen
    hostname=$(echo "$hostname" | tr -s '-')
    hostname=${hostname%-}

    log_debug "Generated hostname: $hostname from email: $email"
    echo "$hostname"
}

# Verify Tailscale installation
verify_installation() {
    log_info "Verifying Tailscale installation..."

    if ! command -v tailscale >/dev/null || ! command -v tailscaled >/dev/null; then
        log_error "Tailscale is not installed. Please run tailscale-install.sh first"
        return 1
    fi

    # Check required directories
    local required_dirs=(
        "${TAILSCALE_BASE_DIR}"
        "${TAILSCALE_STATE_DIR}"
        "${TAILSCALE_RUNTIME_DIR}"
        "${TAILSCALE_LOG_BASE}"
        "${TAILSCALE_LOG_DAEMON_DIR}"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory not found: $dir"
            return 1
        fi
    done
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

    # Start daemon with logging
    tailscaled \
        --verbose="${TAILSCALE_LOG_LEVEL}" \
        --statedir="${TAILSCALE_STATE_DIR}" \
        >> "${TAILSCALE_DAEMON_LOG}" 2>&1 &

    # Wait for daemon to start
    local retries=5
    while ((retries > 0)); do
        if pidof tailscaled >/dev/null; then
            log_debug "Daemon started successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    log_error "Tailscale daemon failed to start"
    tail -n 10 "${TAILSCALE_DAEMON_LOG}" | log_error
    return 1
}

# Configure and start Tailscale
start_tailscale() {
    log_info "Starting Tailscale..."

    local hostname
    if ! hostname=$(generate_hostname); then
        return 1
    fi

    local up_args=(
        "--hostname=${hostname}"
        "--accept-routes=true"
    )

    # Add tags if specified
    if [[ -n "${TAILSCALE_TAGS:-}" ]]; then
        up_args+=("--advertise-tags=${TAILSCALE_TAGS}")
    fi

    log_info "Starting Tailscale with hostname: ${hostname}"
    if ! tailscale up "${up_args[@]}"; then
        log_error "Failed to start Tailscale"
        return 1
    fi

    # Wait for connection
    local timeout="${TAILSCALE_CONNECT_TIMEOUT}"
    local retries="${TAILSCALE_MAX_RETRIES}"

    while ((retries > 0)); do
        if tailscale status | grep -q "^100\."; then
            log_info "Tailscale connected successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep $((timeout / TAILSCALE_MAX_RETRIES))
    done

    log_error "Failed to establish Tailscale connection within timeout"
    return 1
}

# Configure exit node
configure_exit_node() {
    if [[ "${TAILSCALE_EXIT_NODE_ENABLED}" != "true" ]]; then
        log_info "Exit node functionality disabled"
        return 0
    fi

    local proxy_host="${TAILSCALE_DEFAULT_PROXY_HOST}"
    log_info "Configuring exit node (${proxy_host})..."

    # Wait for proxy to be available
    local retries="${TAILSCALE_MAX_RETRIES}"
    local exit_node_ip

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
        sleep $((TAILSCALE_CONNECT_TIMEOUT / TAILSCALE_MAX_RETRIES))
    done

    if [[ -z "${exit_node_ip}" || "${exit_node_ip}" == "null" ]]; then
        log_error "Could not find exit node: ${proxy_host}"
        return 1
    fi

    if ! tailscale set \
        --exit-node="${exit_node_ip}" \
        --exit-node-allow-lan="${TAILSCALE_EXIT_NODE_ALLOW_LAN}"; then
        log_error "Failed to configure exit node"
        return 1
    fi

    log_info "Exit node configured successfully"
}

# Main startup process
main() {
    verify_installation || exit 1
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
