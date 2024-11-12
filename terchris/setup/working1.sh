#!/bin/bash
# File: configure-podman-mac.sh
# Purpose: Install and configure Podman on macOS for devcontainer use
#
# This script provides automated setup of Podman for use with VS Code devcontainers.
# It handles both fresh installations and existing setups, performing these tasks:
#
# 1. Checks/installs Podman (offers Homebrew or manual installation options)
# 2. Manages Podman machine (creates or verifies existing)
# 3. Validates socket configuration
# 4. Verifies setup with hello-world container test
#
# Usage:
#   chmod +x configure-podman-mac.sh
#   ./configure-podman-mac.sh
#
# Requirements:
#   - macOS
#   - Optional: Homebrew for automatic installation

set -e

# Global socket path storage
PODMAN_SOCKET_PATH=""

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

    while [ $attempt -le $max_attempts ]; do
        if podman machine list | grep -q "Currently running"; then
            sleep 2
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    return 1
}

install_homebrew_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            print_error "Failed to install Homebrew"
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

    print_error "Homebrew installation failed. Please install Podman manually:"
    echo "1. Download from https://podman.io/getting-started/installation#macos"
    echo "2. Run installer"
    echo "3. Run this script again"
    exit 1
}

reset_podman_machine() {
    print_step "Resetting Podman machine..."

    podman machine stop >/dev/null 2>&1 || true
    sleep 2
    podman machine rm -f >/dev/null 2>&1 || true
    sleep 2

    echo "Initializing new Podman machine..."
    if ! podman machine init --disk-size 100 --memory 2048 --cpus 2; then
        print_error "Machine initialization failed"
        exit 1
    fi

    echo "Starting Podman machine..."
    if ! podman machine start; then
        print_error "Machine start failed"
        exit 1
    fi

    if ! wait_for_machine; then
        print_error "Machine startup timeout"
        exit 1
    fi

    sleep 5
}

verify_socket() {
    local socket_path=$1

    if [ ! -S "$socket_path" ]; then
        return 1
    fi

    if DOCKER_HOST="unix://$socket_path" podman version >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

setup_podman_machine() {
    print_step "Setting up Podman machine..."

    if podman machine list | grep -q "Currently running"; then
        if verify_socket "/var/run/docker.sock"; then
            echo "✅ Podman machine is running with valid socket"
            return 0
        fi
        print_warning "Existing machine needs reset"
    fi

    reset_podman_machine
}

get_socket_path() {
    print_step "Locating Podman socket..."

    if ! wait_for_machine > /dev/null 2>&1; then
        print_error "Machine not ready"
        return 1
    fi

    # Try default socket first
    PODMAN_SOCKET_PATH="/var/run/docker.sock"
    if [ -S "$PODMAN_SOCKET_PATH" ] && verify_socket "$PODMAN_SOCKET_PATH"; then
        echo "✅ Using default Docker socket"
        return 0
    fi

    local machine_name=$(podman machine list | grep "Currently running" | awk '{print $1}' | tr -d '*')
    if [ -z "$machine_name" ]; then
        print_error "No running machine found"
        return 1
    fi

    PODMAN_SOCKET_PATH=$(podman machine inspect "$machine_name" 2>/dev/null | grep -o '"Path":"[^"]*"' | grep "sock" | head -1 | cut -d'"' -f4)

    if [ -n "$PODMAN_SOCKET_PATH" ] && verify_socket "$PODMAN_SOCKET_PATH"; then
        echo "✅ Using Podman socket"
        return 0
    fi

    print_error "No valid socket found"
    PODMAN_SOCKET_PATH=""
    return 1
}

run_hello_world_test() {
    print_step "Running verification test..."
    local socket_path=$1

    if ! DOCKER_HOST="unix://$socket_path" podman pull hello-world >/dev/null; then
        print_error "Image pull failed"
        return 1
    fi

    if ! DOCKER_HOST="unix://$socket_path" podman run --rm hello-world; then
        print_error "Container test failed"
        return 1
    fi

    DOCKER_HOST="unix://$socket_path" podman rmi hello-world >/dev/null 2>&1 || true
    return 0
}

verify_setup() {
    print_step "Verifying installation..."
    local socket_path=$1

    if ! DOCKER_HOST="unix://$socket_path" podman version >/dev/null 2>&1; then
        print_error "Basic functionality check failed"
        return 1
    fi

    if ! run_hello_world_test "$socket_path"; then
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
        print_error "Socket configuration failed"
        exit 1
    fi

    if ! verify_setup "$PODMAN_SOCKET_PATH"; then
        print_error "Verification failed"
        exit 1
    fi

    echo "======================="
    echo "🎉 Setup Successful!"
    echo ""
    echo "Status:"
    echo "- Podman: $(podman version --format '{{.Client.Version}}')"
    echo "- Socket: $PODMAN_SOCKET_PATH"
    echo "- Ready for devcontainer use"
    echo ""
    echo "Current Images:"
    local images_output
    images_output=$(DOCKER_HOST="unix://$PODMAN_SOCKET_PATH" podman images)
    if [ -z "$(echo "$images_output" | grep -v "REPOSITORY")" ]; then
        echo "No images pulled (normal for fresh install)"
    else
        echo "$images_output"
    fi
    echo ""
    echo "✅ Configuration complete"
}

main
