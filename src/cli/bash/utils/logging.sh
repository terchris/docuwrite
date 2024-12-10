#!/bin/bash
# file: src/cli/bash/utils/logging.sh
# Description: Common logging functions for DocuWrite scripts

# Function to log messages with timestamp
# Arguments:
#   $1 - Message to log
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to log errors and exit
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, defaults to 1)
error() {
    local exit_code=${2:-1}
    log "ERROR: $1" >&2
    exit "$exit_code"
}

# Function to log warnings
# Arguments:
#   $1 - Warning message
warn() {
    log "WARNING: $1" >&2
} 