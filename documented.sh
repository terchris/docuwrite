#!/bin/bash
# File: configure-podman-mac.sh
# Purpose: Install and configure Podman on macOS for devcontainer use
# 
# This script automatically installs and configures Podman for use with devcontainers.
# It provides automatic recovery from common issues and clear error messages.
#
# The script will:
# - Install Podman if not present (using Homebrew or guiding manual installation)
# - Initialize and start Podman machine
# - Ensure socket is properly configured and working
# - Set up shell environment variables
#
# Usage: 
#   1. Make executable: chmod +x configure-podman-mac.sh
#   2. Run: ./configure-podman-mac.sh
#
# Requirements:
#   - macOS
#   - Optional: Homebrew for automatic installation

set -e

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to handle errors
handle_error() {
    print_error "An error occurred in function: $1"
    print_error "Error details: $2"
    echo "Please check the error message above and try again."
    echo "If the problem persists, try these steps:"
    echo "1. podman machine stop"
    echo "2. podman machine rm"
    echo "3. Run this script again"
    exit 1
}

# Trap errors and provide function name where error occurred
trap 'handle_error "${FUNCNAME[0]}" "$BASH_COMMAND"' ERR

install_homebrew_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        print_step "Installing Homebrew (needed for Podman installation)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            print_error "Failed to install Homebrew"
            exit 1
        }
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
}

reset_podman_machine() {
    print_step "Resetting Podman machine..."
    podman machine stop >/dev/null 2>&1 || true
    podman machine rm -f >/dev/null 2>&1 || true
    podman machine init --disk-size 100 --memory 2048 --cpus 2 || {
        print_error "Failed to initialize Podman machine"
        exit 1
    }
    podman machine start || {
        print_error "Failed to start Podman machine"
        exit 1
    }
}

install_podman() {
    print_step "Checking Podman installation..."
    
    local PODMAN_INSTALLED=false
    if command -v podman >/dev/null 2>&1; then
        echo "✅ Podman is already installed ($(podman version --format '{{.Client.Version}}'))"
        PODMAN_INSTALLED=true
    else
        if ! command -v brew >/dev/null 2>&1; then
            install_homebrew_if_needed
        fi

        echo "📦 Installing Podman using Homebrew..."
        if brew install podman; then
            echo "✅ Podman installed successfully"
            PODMAN_INSTALLED=true
        else
            print_error "Failed to install Podman using Homebrew"
            echo "Please install Podman manually:"
            echo "1. Download Podman.dmg from https://podman.io/getting-started/installation#macos"
            echo "2. Double click the downloaded file and follow installation instructions"
            echo "3. Run this script again"
            exit 1
        fi
    fi

    # Verify podman works after installation
    if ! podman version >/dev/null 2>&1; then
        print_error "Podman is installed but not working properly"
        exit 1
    fi
}

verify_socket() {
    local SOCKET_PATH=$1
    local MAX_RETRIES=3
    local RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if [ -S "$SOCKET_PATH" ]; then
            if DOCKER_HOST="unix://$SOCKET_PATH" podman version >/dev/null 2>&1; then
                echo "✅ Socket is functional"
                return 0
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_warning "Socket not working, attempting recovery (attempt $RETRY_COUNT of $MAX_RETRIES)..."
            reset_podman_machine
        fi
    done

    return 1
}

setup_podman_machine() {
    print_step "Setting up Podman machine..."
    
    # Get current machine status
    local MACHINE_STATUS=""
    MACHINE_STATUS=$(podman machine list 2>/dev/null) || MACHINE_STATUS=""
    
    # If machine exists and is running, verify it works
    if echo "$MACHINE_STATUS" | grep -q "Currently running"; then
        local MACHINE_NAME=$(echo "$MACHINE_STATUS" | grep -m1 "Currently running" | awk '{print $1}')
        echo "Found running machine: $MACHINE_NAME"
        
        # Get socket path
        local SOCKET_PATH=$(podman machine inspect "$MACHINE_NAME" | grep -o '"PodmanSocket":{[^}]*}' | grep -o '"Path":"[^"]*"' | cut -d'"' -f4)
        
        if [ -z "$SOCKET_PATH" ]; then
            print_warning "Cannot find socket path, resetting machine..."
            reset_podman_machine
        elif ! verify_socket "$SOCKET_PATH"; then
            print_warning "Socket verification failed, resetting machine..."
            reset_podman_machine
        else
            echo "✅ Existing Podman machine is working correctly"
            return 0
        fi
    else
        # No running machine found, ensure clean slate
        reset_podman_machine
    fi
}

get_socket_path() {
    print_step "Verifying Podman socket..."

    local MACHINE_NAME=$(podman machine list | grep -m1 "Currently running" | awk '{print $1}')
    if [ -z "$MACHINE_NAME" ]; then
        print_error "No running Podman machine found"
        return 1
    fi

    local SOCKET_PATH=$(podman machine inspect "$MACHINE_NAME" | grep -o '"PodmanSocket":{[^}]*}' | grep -o '"Path":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$SOCKET_PATH" ] || [ ! -S "$SOCKET_PATH" ]; then
        print_error "Socket not found or invalid"
        reset_podman_machine
        # Try to get the socket path again after reset
        SOCKET_PATH=$(podman machine inspect "$MACHINE_NAME" | grep -o '"PodmanSocket":{[^}]*}' | grep -o '"Path":"[^"]*"' | cut -d'"' -f4)
    fi

    if [ -z "$SOCKET_PATH" ] || [ ! -S "$SOCKET_PATH" ]; then
        print_error "Failed to establish valid socket path even after reset"
        return 1
    fi

    if ! verify_socket "$SOCKET_PATH"; then
        print_error "Socket verification failed even after reset"
        return 1
    fi

    echo "✅ Socket path verified: $SOCKET_PATH"
    echo "$SOCKET_PATH"
}

configure_shell() {
    local SOCKET_PATH=$1
    print_step "Configuring shell environment..."

    local DOCKER_HOST_CONFIG="export DOCKER_HOST=unix://$SOCKET_PATH"
    
    # Determine user's shell and RC file
    local SHELL_RC="$HOME/.zshrc"
    if [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    # Create RC file if it doesn't exist
    if [ ! -f "$SHELL_RC" ]; then
        touch "$SHELL_RC"
    fi

    # Update or add DOCKER_HOST configuration
    if grep -q "export DOCKER_HOST=.*" "$SHELL_RC"; then
        sed -i.bak "s|export DOCKER_HOST=.*|$DOCKER_HOST_CONFIG|" "$SHELL_RC"
    else
        echo "$DOCKER_HOST_CONFIG" >> "$SHELL_RC"
    fi

    # Export for current session
    export DOCKER_HOST="unix://$SOCKET_PATH"
    
    echo "✅ Shell environment configured"
    echo "ℹ️  Changes will take effect in new terminal windows"
}

verify_setup() {
    print_step "Performing final verification..."
    local SOCKET_PATH=$1
    local TEST_IMAGE="hello-world"

    # Verify socket is working
    if ! DOCKER_HOST="unix://$SOCKET_PATH" podman version >/dev/null 2>&1; then
        print_error "Final socket verification failed"
        return 1
    fi

    # Try pulling a test image
    echo "Testing image pull..."
    if DOCKER_HOST="unix://$SOCKET_PATH" podman pull $TEST_IMAGE >/dev/null 2>&1; then
        echo "✅ Successfully pulled test image"
        DOCKER_HOST="unix://$SOCKET_PATH" podman rmi $TEST_IMAGE >/dev/null 2>&1 || true
    else
        print_warning "Could not pull test image (possible network issue)"
        echo "Basic functionality appears to work, continuing..."
    fi

    return 0
}

# Main execution flow
main() {
    echo "🚀 Starting Podman Setup and Configuration"
    echo "=========================================="

    trap 'echo "Script interrupted. Cleaning up..."; exit 1' INT TERM

    install_podman
    setup_podman_machine

    SOCKET_PATH=$(get_socket_path)
    if [ -z "$SOCKET_PATH" ]; then
        print_error "Failed to establish valid socket path"
        exit 1
    fi

    configure_shell "$SOCKET_PATH"
    
    if ! verify_setup "$SOCKET_PATH"; then
        print_error "Final verification failed"
        exit 1
    fi

    echo "=========================================="
    echo "🎉 Podman Setup Successful!"
    echo ""
    echo "Configuration Summary:"
    echo "- Podman Version: $(podman version --format '{{.Client.Version}}')"
    echo "- Socket Path: $SOCKET_PATH"
    echo "- Environment Variable: DOCKER_HOST=unix://$SOCKET_PATH"
    echo ""
    echo "Next Steps:"
    echo "1. Open a new terminal or run: source $SHELL_RC"
    echo "2. Continue with setting up your devcontainer"
    echo ""
    echo "To verify installation, try:"
    echo "podman images"
}

main
