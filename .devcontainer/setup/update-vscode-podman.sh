#!/bin/bash
# file: .devcontainer/setup/update-vscode-podman.sh
# Description: This script updates the VS Code settings with the Podman socket path.

echo "🔍 Starting Podman socket detection..."

# First check if podman machine exists and get its name
if ! command -v podman >/dev/null 2>&1; then
    echo "❌ Podman is not installed"
    exit 1
fi

# Check for running podman machine
PODMAN_MACHINE_NAME="podman-machine-default"
if ! podman machine list | grep -q "$PODMAN_MACHINE_NAME.*Currently running"; then
    echo "❌ Podman machine is not running"
    exit 1
fi

# Get socket path directly from machine inspection
echo "📋 Running: podman machine inspect ${PODMAN_MACHINE_NAME}"
INSPECT_OUTPUT=$(podman machine inspect ${PODMAN_MACHINE_NAME})
echo "🔍 Inspect output: $INSPECT_OUTPUT"

DOCKER_HOST=$(echo "$INSPECT_OUTPUT" | grep -o '"Path": "[^"]*"' | grep "podman-machine-default-api.sock" | cut -d'"' -f4)
echo "🔌 Found socket path: $DOCKER_HOST"

if [ -z "$DOCKER_HOST" ] || [ ! -S "$DOCKER_HOST" ]; then
    echo "❌ Could not find Podman socket path or socket does not exist"
    exit 1
fi

# Format the Docker host URI
if [[ "$DOCKER_HOST" != unix://* ]]; then
    DOCKER_HOST_URI="unix://${DOCKER_HOST}"
else
    DOCKER_HOST_URI="$DOCKER_HOST"
fi

# Show the environment file we're writing to
ENV_FILE="${GITHUB_ENV:-$HOME/.env}"
echo "📝 Writing to environment file: $ENV_FILE"

# Export both the socket path and Docker host URI
echo "PODMAN_SOCKET=${DOCKER_HOST}" >> "$ENV_FILE"
echo "DOCKER_HOST=${DOCKER_HOST_URI}" >> "$ENV_FILE"

echo "✅ Found Podman socket at: $DOCKER_HOST"
echo "✅ Docker Host URI: $DOCKER_HOST_URI"
echo "📄 Current environment file contents:"
cat "$ENV_FILE"
