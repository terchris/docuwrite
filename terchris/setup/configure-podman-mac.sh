#!/bin/bash
# File: configure-podman-mac.sh
# Purpose: Install and configure Podman on macOS for devcontainer use
#
# This script handles fresh Podman installations on macOS, configuring it for
# use with VS Code devcontainers. It performs these tasks:
# 1. Installs Podman (via Homebrew if available, or guides manual installation)
# 2. Sets up Podman machine in rootful mode
# 3. Configures API socket for devcontainer access
# 4. Verifies installation with basic container test
#
# Usage:
#   chmod +x configure-podman-mac.sh
#   ./configure-podman-mac.sh
#
# Requirements:
#   - macOS (Intel or Apple Silicon)
#   - Optional: Homebrew for automatic installation

set -e

# Global variables
PODMAN_SOCKET_PATH=""
MACHINE_NAME="podman-machine-default"

# Output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

wait_for_machine() {
    local max_attempts=30
    local attempt=1
    echo "Waiting for machine to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if podman machine list | grep -q "Currently running"; then
            sleep 2
            return 0
        fi
        echo "Attempt $attempt of $max_attempts..."
        sleep 1
        attempt=$((attempt + 1))
    done

    return 1
}

install_homebrew_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            print_error "Homebrew installation failed"
            echo "Please install Homebrew manually from https://brew.sh"
            exit 1
        }

        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
}

install_podman() {
    print_step "Installing Podman..."

    if command -v podman >/dev/null 2>&1; then
        echo "✅ Podman is already installed ($(podman version --format '{{.Client.Version}}'))"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        install_homebrew_if_needed
    fi

    echo "📦 Installing Podman using Homebrew..."
    if brew install podman; then
        echo "✅ Podman installed successfully"
        return 0
    fi

    print_error "Homebrew installation failed"
    echo "Please install Podman manually:"
    echo "1. Download from https://podman.io/getting-started/installation#macos"
    echo "2. Install the downloaded package"
    echo "3. Run this script again"
    exit 1
}

verify_socket() {
    local socket_path=$1
    echo "Verifying socket at: $socket_path"

    if [ ! -S "$socket_path" ]; then
        print_error "Socket file not found"
        return 1
    fi

    echo "Testing socket functionality..."
    if ! DOCKER_HOST="unix://$socket_path" podman version >/dev/null 2>&1; then
        print_error "Socket not responding to API calls"
        return 1
    fi

    if ! DOCKER_HOST="unix://$socket_path" podman ps >/dev/null 2>&1; then
        print_error "Socket not working for container operations"
        return 1
    fi

    echo "✅ Socket verified"
    return 0
}

configure_new_machine() {
    echo "Initializing new Podman machine..."

    local arch_type="standard"
    if [[ $(uname -m) == 'arm64' ]]; then
        arch_type="Apple Silicon"
    fi
    echo "Configuring for $arch_type Mac..."

    podman machine init \
        --disk-size 100 \
        --memory 2048 \
        --cpus 2 \
        --rootful \
        --now \
        "$MACHINE_NAME" || {
            print_error "Machine initialization failed"
            exit 1
        }

    echo "Starting Podman machine..."
    if ! podman machine start "$MACHINE_NAME"; then
        print_error "Machine start failed"
        exit 1
    fi

    if ! wait_for_machine; then
        print_error "Machine startup timeout"
        exit 1
    fi

    sleep 5
}

setup_podman_machine() {
    print_step "Setting up Podman machine..."

    # Check existing machine
    if podman machine list | grep -q "$MACHINE_NAME"; then
        echo "Found existing machine, checking configuration..."

        if podman machine list | grep -q "Currently running"; then
            if podman machine inspect "$MACHINE_NAME" | grep -q '"Rootful": true'; then
                if verify_socket "/var/run/docker.sock"; then
                    echo "✅ Existing machine is properly configured"
                    return 0
                fi
            fi
        fi

        print_warning "Existing machine needs reconfiguration"
        echo "Removing existing machine..."
        podman machine stop "$MACHINE_NAME" >/dev/null 2>&1 || true
        sleep 2
        podman machine rm -f "$MACHINE_NAME" >/dev/null 2>&1 || true
        sleep 2
    fi

    configure_new_machine

    # Verify API forwarding
    echo "Verifying API forwarding..."
    local max_attempts=10
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if verify_socket "/var/run/docker.sock"; then
            echo "✅ API forwarding configured successfully"
            return 0
        fi
        echo "Waiting for API socket... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "API forwarding configuration failed"
    echo "Try these steps:"
    echo "1. Run: podman machine stop && podman machine start"
    echo "2. Check logs: podman machine logs"
    exit 1
}

get_socket_path() {
    print_step "Locating Podman socket..."

    # Check for default socket
    PODMAN_SOCKET_PATH="/var/run/docker.sock"
    if [ -S "$PODMAN_SOCKET_PATH" ] && verify_socket "$PODMAN_SOCKET_PATH"; then
        echo "✅ Using default Docker socket"
        return 0
    fi

    print_error "Default socket not working"
    echo "Attempting to reset machine configuration..."
    setup_podman_machine

    if [ -S "$PODMAN_SOCKET_PATH" ] && verify_socket "$PODMAN_SOCKET_PATH"; then
        echo "✅ Socket configured successfully after reset"
        return 0
    fi

    print_error "Socket configuration failed"
    return 1
}

run_hello_world_test() {
    print_step "Running verification test..."
    local socket_path=$1

    echo "Pulling test image..."
    if ! DOCKER_HOST="unix://$socket_path" podman pull hello-world >/dev/null; then
        print_error "Failed to pull test image"
        return 1
    fi

    echo "Running test container..."
    if ! DOCKER_HOST="unix://$socket_path" podman run --rm hello-world; then
        print_error "Test container failed"
        return 1
    fi

    echo "Cleaning up..."
    DOCKER_HOST="unix://$socket_path" podman rmi hello-world >/dev/null 2>&1 || true
    echo "✅ Test completed successfully"
    return 0
}

verify_setup() {
    print_step "Performing verification..."
    local socket_path=$1

    if ! run_hello_world_test "$socket_path"; then
        print_error "Verification failed"
        return 1
    fi

    return 0
}

main() {
    echo "🚀 Starting Podman Setup"
    echo "======================="

    install_podman
    setup_podman_machine

    if ! get_socket_path; then
        print_error "Setup failed"
        exit 1
    fi

    if ! verify_setup "$PODMAN_SOCKET_PATH"; then
        print_error "Verification failed"
        exit 1
    fi

    echo "======================="
    echo "🎉 Setup Successful!"
    echo ""
    echo "Configuration Summary:"
    echo "- Podman Version: $(podman version --format '{{.Client.Version}}')"
    echo "- Machine Type: Rootful"
    echo "- Socket Path: $PODMAN_SOCKET_PATH"
    echo ""
    echo "✅ Ready for devcontainer use"
}

main
