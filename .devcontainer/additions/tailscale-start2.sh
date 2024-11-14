#!/bin/bash
# File: .devcontainer/additions/tailscale-start2.sh
#
# Purpose:
#   Starts and configures Tailscale in a devcontainer environment with proper
#   sequencing, status tracking, and comprehensive network verification.
#
# Author: Terje Christensen
# Created: November 2024
#

set -euo pipefail

# Source all library files
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly SCRIPT_DIR

# List of required library files
readonly REQUIRED_LIBS=(
    "common"     # Common utilities and logging
    "network"    # Network testing and verification
    "status"     # Tailscale status management
    "exitnode"   # Exit node configuration
    "config"     # Configuration management
    "report"     # Status reporting and display
)

# Source library files
for lib in "${REQUIRED_LIBS[@]}"; do
    lib_file="${SCRIPT_DIR}/tailscale-lib-${lib}.sh"
    if [[ ! -f "$lib_file" ]]; then
        echo "Error: Required library file not found: $lib_file"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_file"
done

# Pre-connection setup and verification
prepare_environment() {
    log_info "Preparing environment..."

    # Load environment configuration
    display_setup_progress "Environment" "Loading configuration..." 0 4
    if ! load_environment; then
        log_error "Failed to load environment configuration"
        return "$EXIT_ENV_ERROR"
    fi

    # Verify required capabilities
    display_setup_progress "Environment" "Checking capabilities..." 1 4
    if ! check_capabilities; then
        log_error "Failed to verify required capabilities"
        return "$EXIT_ENV_ERROR"
    fi

    # Check required tools
    display_setup_progress "Environment" "Checking dependencies..." 2 4
    if ! check_dependencies; then
        log_error "Failed to verify required tools"
        return "$EXIT_ENV_ERROR"
    fi

    # Collect initial network state
    display_setup_progress "Environment" "Collecting initial state..." 3 4
    if ! collect_initial_state; then
        log_error "Failed to collect initial network state"
        return "$EXIT_NETWORK_ERROR"
    fi

    display_setup_progress "Environment" "Environment prepared successfully" 4 4
    return "$EXIT_SUCCESS"
}

# Initialize Tailscale service
initialize_tailscale() {
    log_info "Initializing Tailscale..."

    # Generate unique hostname
    local hostname
    hostname=$(generate_unique_hostname)

    # Stop daemon
    stop_tailscale_daemon || return 1


    # Start daemon
    start_tailscale_daemon || return 1

    # Connect with unique hostname
    establish_tailscale_connection "$hostname" || return 1

    # Verify connection type -- WHY ?
    detect_connection_type

    return 0
}

# Configure routing and exit node
configure_routing() {
    log_info "Configuring Tailscale routing..."

    # find the exit node and make sure we can reach it
    local exit_node_info
    exit_node_info=$(find_exit_node) || return 1

    # Setup exit node routing
    setup_exit_node "$exit_node_info" || return 1

    # Verify routing configuration
    verify_exit_routing "$exit_node_info" || return 1

    return 0
}

# Final verification and documentation
finalize_setup() {
    log_info "Finalizing Tailscale setup..."

    # Collect final state
    collect_final_state || return 1

    # Generate and save configuration
    generate_configuration || return 1


    return 0
}

# Main process
main() {
    log_info "Starting Tailscale setup process..."

    # Check root access immediately
    if ! check_root; then
        return "$EXIT_ENV_ERROR"  # check_root already outputs the error message
    fi

    # Record start time for duration calculation
    local start_time
    start_time=$(date +%s)

    # Phase 1: Environment preparation
    if ! prepare_environment; then
        log_error "Failed to prepare environment"
        return "$EXIT_ENV_ERROR"
    fi

    log_info "Environment preparation completed successfully"


    # Phase 2: Tailscale initialization
    if ! initialize_tailscale; then
        log_error "Failed to initialize Tailscale"
        return "$EXIT_TAILSCALE_ERROR"
    fi


    # Phase 3: Routing configuration
    if ! configure_routing; then
        log_error "Failed to configure routing"
        return "$EXIT_EXITNODE_ERROR"
    fi


    # Phase 4: Finalization
    if ! finalize_setup; then
        log_error "Failed to finalize setup"
        return "$EXIT_VERIFY_ERROR"
    fi


    # Record end time
    local end_time
    end_time=$(date +%s)

    # Load final configuration for summary
    local config_json
    config_json=$(load_configuration)

    # Display completion summary with timing information
    display_completion_summary "$config_json" "$start_time" "$end_time"
    return "$EXIT_SUCCESS"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
