#!/bin/bash
# File: .devcontainer/additions/tailscale-install.sh
#
# Purpose: Installs Tailscale and sets up required directories in a devcontainer
#
# Usage: sudo bash tailscale-install.sh [--force]
#
# Options:
#   --force    Force reinstall if already installed

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
    local required_caps=("NET_ADMIN" "NET_RAW" "SYS_ADMIN" "AUDIT_WRITE")
    local missing_caps=()

    for cap in "${required_caps[@]}"; do
        if ! grep -q "CapEff.*$cap" /proc/self/status 2>/dev/null; then
            missing_caps+=("$cap")
        fi
    done

    if [[ ${#missing_caps[@]} -ne 0 ]]; then
        log_error "Missing required capabilities: ${missing_caps[*]}"
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
}

# Setup network requirements
setup_networking() {
    log_info "Setting up networking requirements..."

    # Setup TUN device
    if [[ ! -d /dev/net ]]; then
        mkdir -p /dev/net
    fi
    if [[ ! -c /dev/net/tun ]]; then
        mknod /dev/net/tun c 10 200
    fi
    chmod 666 /dev/net/tun

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
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
    setup_networking || exit 1
    create_directories || exit 1
    install_tailscale || exit 1

    log_info "Installation completed successfully"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
