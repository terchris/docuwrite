#!/bin/bash
# File: .devcontainer/additions/tailscale-stop.sh
#
# Purpose: Stops Tailscale service and optionally cleans up resources
#
# Usage: sudo bash tailscale-stop.sh [OPTIONS]
#
# Options:
#   --force     Force stop if graceful shutdown fails
#   --clean     Remove state files after stopping

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
FORCE_STOP=false
CLEAN_STATE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_STOP=true
            shift
            ;;
        --clean)
            CLEAN_STATE=true
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Force stop function
force_stop() {
    log_warn "Forcing Tailscale to stop..."
    pkill -9 tailscaled || true
    return 0
}

# Cleanup state
cleanup_state() {
    log_info "Cleaning up Tailscale state..."

    # Stop any running processes first
    if pidof tailscaled >/dev/null; then
        force_stop
    fi

    # Remove state files
    rm -rf "${TAILSCALE_STATE_DIR:?}"/*
    log_info "State directory cleaned"

    # Optionally clear logs
    if [[ -d "${TAILSCALE_LOG_BASE}" ]]; then
        find "${TAILSCALE_LOG_BASE}" -type f -name "*.log" -delete
        log_info "Log files cleaned"
    fi
}

# Graceful shutdown
graceful_shutdown() {
    log_info "Initiating graceful shutdown of Tailscale..."

    # Check if Tailscale is running
    if ! pidof tailscaled >/dev/null; then
        log_info "Tailscale is not running"
        return 0
    fi

    # Attempt to logout first
    if tailscale status >/dev/null 2>&1; then
        log_debug "Logging out of Tailscale..."
        tailscale logout || true
    fi

    # Bring down the interface
    log_debug "Bringing down Tailscale interface..."
    if ! tailscale down; then
        log_error "Failed to bring down Tailscale interface"
        return 1
    fi

    # Stop the daemon
    local pid
    pid=$(pidof tailscaled) || true
    if [[ -n "$pid" ]]; then
        log_debug "Stopping Tailscale daemon (PID: $pid)..."
        kill "$pid"

        # Wait for process to end
        local retries=5
        while ((retries > 0)); do
            if ! kill -0 "$pid" 2>/dev/null; then
                log_info "Tailscale stopped successfully"
                return 0
            fi
            retries=$((retries - 1))
            sleep 1
        done

        log_error "Daemon did not stop gracefully"
        return 1
    fi

    return 0
}

# Main stop process
main() {
    # Attempt graceful shutdown first
    if ! graceful_shutdown; then
        if [[ "$FORCE_STOP" == "true" ]]; then
            force_stop
        else
            log_error "Failed to stop Tailscale gracefully. Use --force to force stop."
            exit 1
        fi
    fi

    # Clean up if requested
    if [[ "$CLEAN_STATE" == "true" ]]; then
        cleanup_state
    fi

    log_info "Tailscale shutdown completed"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
