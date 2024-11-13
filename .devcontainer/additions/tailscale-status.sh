#!/bin/bash
# File: .devcontainer/additions/tailscale-status.sh
#
# Purpose: Shows Tailscale status and diagnostics information
#
# Usage: sudo .devcontainer/additions/tailscale-status.sh [OPTIONS]
#
# Options:
#   --json     Output in JSON format
#   --check    Only check if running (exit 0 if running, 1 if not)
#   --debug    Show additional debug information

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

# Parse arguments
JSON_OUTPUT=false
CHECK_ONLY=false
SHOW_DEBUG=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --debug)
            SHOW_DEBUG=true
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Check if service is running
check_running() {
    if ! pidof tailscaled >/dev/null; then
        return 1
    fi
    if ! tailscale status >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Get basic connection info
get_connection_info() {
    local status
    status=$(tailscale status --json)
    local ip
    ip=$(echo "$status" | jq -r '.Self.TailscaleIPs[0]')
    local hostname
    hostname=$(echo "$status" | jq -r '.Self.HostName')
    local exit_node
    exit_node=$(echo "$status" | jq -r '.ExitNode // ""')

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        jq -n \
            --arg ip "$ip" \
            --arg hostname "$hostname" \
            --arg exit_node "$exit_node" \
            '{
                "ip": $ip,
                "hostname": $hostname,
                "exit_node": $exit_node,
                "running": true
            }'
    else
        echo "Tailscale Status:"
        echo "  IP: $ip"
        echo "  Hostname: $hostname"
        echo "  Exit Node: ${exit_node:-None}"
    fi
}

# Get debug information
get_debug_info() {
    local daemon_log_tail
    daemon_log_tail=$(tail -n 5 "${TAILSCALE_DAEMON_LOG}" 2>/dev/null || echo "No daemon log available")
    local netcheck
    netcheck=$(tailscale netcheck 2>/dev/null || echo "Netcheck failed")

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        jq -n \
            --arg daemon_log "$daemon_log_tail" \
            --arg netcheck "$netcheck" \
            '{
                "daemon_log": $daemon_log,
                "netcheck": $netcheck
            }'
    else
        echo
        echo "Debug Information:"
        echo "  Last daemon log entries:"
        echo "$daemon_log_tail" | sed 's/^/    /'
        echo
        echo "  Network check:"
        echo "$netcheck" | sed 's/^/    /'
    fi
}

# Get full status
get_full_status() {
    if ! check_running; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            jq -n '{"running": false, "error": "Tailscale is not running"}'
        else
            log_error "Tailscale is not running"
        fi
        return 1
    fi

    get_connection_info

    if [[ "$SHOW_DEBUG" == "true" ]]; then
        get_debug_info
    fi

    # Show configuration info if not in JSON mode
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo
        echo "Configuration:"
        echo "  User Email: ${TAILSCALE_USER_EMAIL}"
        echo "  Exit Node Enabled: ${TAILSCALE_EXIT_NODE_ENABLED}"
        echo "  Default Proxy: ${TAILSCALE_DEFAULT_PROXY_HOST}"
        echo "  Tags: ${TAILSCALE_TAGS}"
    fi
}

# Main process
main() {
    if [[ "$CHECK_ONLY" == "true" ]]; then
        if check_running; then
            exit 0
        else
            exit 1
        fi
    fi

    get_full_status
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
