#!/bin/bash
# File: .devcontainer/additions/tailscale-install.sh
#
# Purpose: Installs Tailscale and sets up required directories in a devcontainer
#
# Usage: sudo .devcontainer/additions/tailscale-install.sh [--force]
#
# Options:
#   --force    Force reinstall if already installed

set -euo pipefail

# Track if we had any errors
INSTALL_SUCCESS=false

# Cleanup and exit handler
cleanup() {
    local exit_code=$?
    if [[ "$INSTALL_SUCCESS" != "true" ]]; then
        log_error "Installation failed"
        exit 1
    fi
    exit $exit_code
}

# Set trap
trap cleanup EXIT

# Load environment variables
if [[ -f "/workspace/.devcontainer.extend/tailscale.env" ]]; then
    # shellcheck source=/dev/null
    source "/workspace/.devcontainer.extend/tailscale.env"
else
    echo "Error: tailscale.env not found in /workspace/.devcontainer.extend/"
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
FORCE_INSTALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Check for required capabilities
check_capabilities() {
    log_info "Checking container capabilities..."

    # Install capsh if not present
    if ! command -v capsh >/dev/null; then
        log_info "Installing libcap2-bin for capability checking..."
        apt-get update -qq && apt-get install -y libcap2-bin >/dev/null 2>&1
    fi

    # Check using capsh --print
    local current_caps
    current_caps=$(capsh --print 2>/dev/null | grep "Current:" || echo "")

    # Check for all required capabilities
    if ! echo "$current_caps" | grep -q "cap_net_admin" || \
       ! echo "$current_caps" | grep -q "cap_net_raw" || \
       ! echo "$current_caps" | grep -q "cap_sys_admin" || \
       ! echo "$current_caps" | grep -q "cap_audit_write"; then

        log_error "Missing required capabilities"
        log_error "Current capabilities: $current_caps"
        log_error "Please ensure your devcontainer.json includes:"
        cat << EOF
"runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW",
    "--cap-add=SYS_ADMIN",
    "--cap-add=AUDIT_WRITE",
    "--device=/dev/net/tun:/dev/net/tun",
    "--privileged"
]
EOF
        return 1
    fi

    log_info "All required capabilities are present"
    return 0
}

# Verify network requirements
verify_networking() {
    log_info "Verifying networking requirements..."

    # Verify TUN device setup
    if [[ -c /dev/net/tun ]]; then
        log_info "TUN device is properly configured:"
        ls -l /dev/net/tun
        return 0  # Indicate success
    else
        log_error "TUN device is not configured correctly."
        log_info "Attempting to set up TUN device..."

        # Setup TUN device if it doesn't exist
        if [[ ! -d /dev/net ]]; then
            mkdir -p /dev/net
        fi
        if [[ ! -c /dev/net/tun ]]; then
            mknod /dev/net/tun c 10 200
        fi
        chmod 666 /dev/net/tun

        # Verify again to ensure setup was successful
        if [[ -c /dev/net/tun ]]; then
            log_info "TUN device has been set up successfully:"
            ls -l /dev/net/tun
            return 0  # Indicate success
        else
            log_error "Failed to set up TUN device."
            return 1  # Indicate failure
        fi
    fi
}


# Create required directories
create_directories() {
    log_info "Creating required directories..."

    # Create directories with proper permissions
    local dirs=(
        "${TAILSCALE_BASE_DIR}"
        "${TAILSCALE_STATE_DIR}"
        "${TAILSCALE_RUNTIME_DIR}"
        "${TAILSCALE_LOG_BASE}"
        "${TAILSCALE_LOG_DAEMON_DIR}"
        "${TAILSCALE_LOG_AUDIT_DIR}"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod "${TAILSCALE_DIR_MODE}" "$dir"
    done

    # Initialize log files
    touch "${TAILSCALE_DAEMON_LOG}" "${TAILSCALE_SETUP_LOG}"
    chmod "${TAILSCALE_FILE_MODE}" "${TAILSCALE_DAEMON_LOG}" "${TAILSCALE_SETUP_LOG}"
}

# Install Tailscale
install_tailscale() {
    log_info "Installing Tailscale..."

    if command -v tailscale >/dev/null && [[ "$FORCE_INSTALL" != "true" ]]; then
        log_info "Tailscale is already installed. Use --force to reinstall."
        return 0
    fi

    # Install required packages
    log_debug "Installing required packages..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        curl \
        iptables \
        iproute2 \
        iputils-ping \
        traceroute \
        >/dev/null 2>&1



    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh

    # Verify installation
    if ! command -v tailscale >/dev/null; then
        log_error "Tailscale installation failed"
        return 1
    fi

    log_info "Tailscale installed successfully"
}

# Main installation process
main() {
    log_info "Starting Tailscale installation..."

    check_capabilities || exit 1
    verify_networking || exit 1
    create_directories || exit 1
    install_tailscale || exit 1

    INSTALL_SUCCESS=true
    log_info "Installation completed successfully"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
