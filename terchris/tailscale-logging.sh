#!/bin/bash
# File: .devcontainer/additions/tailscale-logging.sh
#
# Purpose: Shared logging functions for Tailscale scripts with log rotation
# and configurable verbosity
#
# Usage: source tailscale-logging.sh
#
# Environment variables:
#   TAILSCALE_LOG_LEVEL: debug|info|warn|error (default: info)
#   TAILSCALE_LOG_FILE: Path to log file (default: /var/log/tailscale/setup.log)
#   TAILSCALE_LOG_TO_CONSOLE: true|false (default: false)
#   TAILSCALE_MAX_LOG_SIZE: Maximum log size in MB (default: 10)
#   TAILSCALE_MAX_LOG_FILES: Number of rotated files to keep (default: 3)

# Default configuration
TAILSCALE_LOG_LEVEL=${TAILSCALE_LOG_LEVEL:-info}
TAILSCALE_LOG_FILE=${TAILSCALE_LOG_FILE:-/var/log/tailscale/setup.log}
TAILSCALE_LOG_TO_CONSOLE=${TAILSCALE_LOG_TO_CONSOLE:-false}
TAILSCALE_MAX_LOG_SIZE=${TAILSCALE_MAX_LOG_SIZE:-10}
TAILSCALE_MAX_LOG_FILES=${TAILSCALE_MAX_LOG_FILES:-3}

# Log levels
declare -A TAILSCALE_LOG_LEVELS=([debug]=0 [info]=1 [warn]=2 [error]=3)
TAILSCALE_CURRENT_LOG_LEVEL=${TAILSCALE_LOG_LEVELS[$TAILSCALE_LOG_LEVEL]}

# Rotate logs if needed
tailscale_rotate_logs() {
    local log_file="$1"
    local max_size=$((TAILSCALE_MAX_LOG_SIZE * 1024 * 1024))

    if [[ -f "$log_file" ]]; then
        local size
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file")

        if (( size > max_size )); then
            rm -f "${log_file}.${TAILSCALE_MAX_LOG_FILES}.gz" 2>/dev/null

            for i in $(seq $((TAILSCALE_MAX_LOG_FILES - 1)) -1 1); do
                [[ -f "${log_file}.$i.gz" ]] && mv "${log_file}.$i.gz" "${log_file}.$((i + 1)).gz"
            done

            gzip -c "$log_file" > "${log_file}.1.gz"
            : > "$log_file"
        fi
    fi
}

# Generic logging function
tailscale_log() {
    local level="$1"
    local message="$2"
    local level_num=${TAILSCALE_LOG_LEVELS[$level]}

    if (( level_num >= TAILSCALE_CURRENT_LOG_LEVEL )); then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local log_message="[${timestamp}] [${level^^}] $message"

        local log_dir
        log_dir=$(dirname "$TAILSCALE_LOG_FILE")
        [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"

        tailscale_rotate_logs "$TAILSCALE_LOG_FILE"

        echo "$log_message" >> "$TAILSCALE_LOG_FILE"
        [[ "$TAILSCALE_LOG_TO_CONSOLE" == "true" ]] && echo "$log_message" >&2
    fi
}

# Individual logging functions
log_debug() { tailscale_log debug "$*"; }
log_info() { tailscale_log info "$*"; }
log_warn() { tailscale_log warn "$*"; }
log_error() { tailscale_log error "$*"; }

# Dump logs for debugging
tailscale_dump_logs() {
    local lines=${1:-100}
    echo "=== Last $lines lines of Tailscale log ==="
    tail -n "$lines" "$TAILSCALE_LOG_FILE"
    echo "=== End of log dump ==="
}

# Clean old logs
tailscale_clean_old_logs() {
    find "$(dirname "$TAILSCALE_LOG_FILE")" -name "$(basename "$TAILSCALE_LOG_FILE").*" -mtime +30 -delete
}
