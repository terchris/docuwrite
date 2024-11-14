#!/bin/bash
# File: .devcontainer/additions/tailscale-lib-config.sh
#
# Purpose:
#   Manages Tailscale configuration generation, saving, and loading.
#   Handles configuration file management and state tracking.
#
# Dependencies:
#   - tailscale-lib-common.sh : Common utilities and logging
#   - tailscale-lib-status.sh : Status management
#   - tailscale-lib-network.sh : Network information
#   - jq : JSON processing
#
# Author: Terje Christensen
# Created: November 2024

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly"
    exit 1
fi

# Configuration state tracking
declare -g INITIAL_STATE=""
declare -g FINAL_STATE=""
declare -g CONFIG_VERSION="1.0.0"

# Configuration schema version
readonly CONFIG_SCHEMA_VERSION="1.0.0"

# Save initial state
save_initial_state() {
    local network_state="$1"

    log_info "Saving initial state..."

    if [[ -z "$network_state" ]]; then
        log_error "No network state provided"
        return "$EXIT_ENV_ERROR"
    fi

    # Add metadata to state
    INITIAL_STATE=$(jq -n \
        --arg version "$CONFIG_SCHEMA_VERSION" \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --argjson state "$network_state" \
        '{
            version: $version,
            timestamp: $timestamp,
            state: $state
        }')

    return 0
}

# Save final state
save_final_state() {
    local status_json="$1"
    local network_state="$2"
    local exit_node_info="$3"

    log_info "Saving final state..."

    if [[ -z "$status_json" || -z "$network_state" || -z "$exit_node_info" ]]; then
        log_error "Missing required state information"
        return "$EXIT_ENV_ERROR"
    fi

    # Create comprehensive final state
    FINAL_STATE=$(jq -n \
        --arg version "$CONFIG_SCHEMA_VERSION" \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --argjson status "$status_json" \
        --argjson network "$network_state" \
        --argjson exitnode "$exit_node_info" \
        '{
            version: $version,
            timestamp: $timestamp,
            status: $status,
            network: $network,
            exitNode: $exitnode
        }')

    return 0
}

# Generate complete configuration
generate_configuration() {
    local config_file="$TAILSCALE_CONF_FILE"
    local status_json
    status_json=$(get_tailscale_status true)

    # Verify JSON validity
    if ! echo "$status_json" | jq '.' >/dev/null 2>&1; then
        log_error "Invalid Tailscale status JSON"
        return "$EXIT_ENV_ERROR"
    fi

    # Convert initial and final states to JSON if they are empty
    [[ -z "$INITIAL_STATE" ]] && INITIAL_STATE="{}"
    [[ -z "$FINAL_STATE" ]] && FINAL_STATE="{}"

    log_info "Generating Tailscale configuration..."

    # Create comprehensive configuration
    local config_json
    config_json=$(jq -n \
        --arg version "$CONFIG_SCHEMA_VERSION" \
        --argjson status "$status_json" \
        --argjson initial "$INITIAL_STATE" \
        --argjson final "$FINAL_STATE" \
        '{
            schemaVersion: $version,
            containerIdentity: {
                hostname: $status.Self.HostName,
                dnsName: $status.Self.DNSName,
                tailscaleIP: $status.Self.TailscaleIPs[0],
                created: ($status.Self.Created | split("T")[0]),
                derpRegion: $status.Self.Relay
            },
            tailnet: {
                name: $status.CurrentTailnet.Name,
                magicDNSSuffix: $status.MagicDNSSuffix,
                magicDNSEnabled: $status.CurrentTailnet.MagicDNSEnabled
            },
            userInfo: ($status.User | to_entries[] |
                    select(.value.LoginName != "tagged-devices") |
                    .value | {
                loginName: .LoginName,
                displayName: .DisplayName,
                profilePicURL: .ProfilePicURL
            }),
            exitNode: (
                if $status.ExitNodeStatus != null then
                $status.Peer[] | select(.ExitNode == true) |
                {
                    host: .HostName,
                    ip: .TailscaleIPs[0],
                    connection: .CurAddr,
                    traffic: {
                        rx: .RxBytes,
                        tx: .TxBytes
                    }
                }
                else null end
            ),
            capMap: $status.Self.CapMap,
            networkState: {
                initial: $initial,
                final: $final
            },
            configGenerated: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }')

    # Create backup if file exists
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.$(date +%Y%m%d_%H%M%S).bak"
        log_info "Creating backup of existing configuration: ${backup_file}"
        cp "$config_file" "$backup_file" || log_warn "Failed to create backup"
    fi

    # Save configuration
    if ! echo "$config_json" | jq '.' > "$config_file"; then
        log_error "Failed to save configuration to ${config_file}"
        return "$EXIT_ENV_ERROR"
    fi

    chmod 600 "$config_file"
    log_info "Configuration saved to ${config_file}"
    return 0
}

# Load existing configuration
load_configuration() {
    local config_file="$TAILSCALE_CONF_FILE"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return "$EXIT_ENV_ERROR"
    fi

    if ! jq '.' "$config_file" >/dev/null 2>&1; then
        log_error "Invalid JSON in configuration file"
        return "$EXIT_ENV_ERROR"
    fi

    # Validate schema version
    local config_version
    config_version=$(jq -r '.schemaVersion' "$config_file")
    if [[ "$config_version" != "$CONFIG_SCHEMA_VERSION" ]]; then
        log_error "Configuration schema version mismatch"
        log_error "Expected: ${CONFIG_SCHEMA_VERSION}, Found: ${config_version}"
        return "$EXIT_ENV_ERROR"
    fi

    cat "$config_file"
    return 0
}

# Validate configuration
validate_configuration() {
    local config_json="$1"

    log_info "Validating configuration..."

    # Required fields
    local required_fields=(
        ".containerIdentity.hostname"
        ".containerIdentity.tailscaleIP"
        ".tailnet.name"
        ".userInfo.loginName"
        ".capMap"
        ".configGenerated"
    )

    local missing_fields=()
    for field in "${required_fields[@]}"; do
        if ! echo "$config_json" | jq -e "$field" >/dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done

    if ((${#missing_fields[@]} > 0)); then
        log_error "Configuration validation failed. Missing fields:"
        for field in "${missing_fields[@]}"; do
            log_error "- $field"
        done
        return "$EXIT_ENV_ERROR"
    fi

    # Validate values
    local hostname
    hostname=$(echo "$config_json" | jq -r '.containerIdentity.hostname')
    local expected_hostname
    expected_hostname="devcontainer-$(echo "${TAILSCALE_USER_EMAIL%@*}" | tr '.' '-')"

    if [[ "$hostname" != "$expected_hostname"* ]]; then
        log_error "Invalid hostname: ${hostname}"
        log_error "Expected pattern: ${expected_hostname}*"
        return "$EXIT_ENV_ERROR"
    fi

    # Check exit node configuration if enabled
    if [[ "${TAILSCALE_EXIT_NODE_ENABLED:-false}" == "true" ]]; then
        if ! echo "$config_json" | jq -e '.exitNode != null' >/dev/null; then
            log_error "Exit node configuration missing but enabled in settings"
            return "$EXIT_ENV_ERROR"
        fi
    fi

    log_info "Configuration validation successful"
    return 0
}

# Update specific configuration fields
update_configuration() {
    local config_file="$TAILSCALE_CONF_FILE"
    local updates="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return "$EXIT_ENV_ERROR"
    fi

    # Create backup
    local backup_file="${config_file}.$(date +%Y%m%d_%H%M%S).bak"
    cp "$config_file" "$backup_file" || log_warn "Failed to create backup"

    # Apply updates
    local updated_config
    updated_config=$(jq --argjson updates "$updates" '. * $updates' "$config_file")

    # Validate updated configuration
    if ! validate_configuration "$updated_config"; then
        log_error "Updated configuration failed validation"
        # Restore backup
        cp "$backup_file" "$config_file"
        return "$EXIT_ENV_ERROR"
    fi

    # Save updated configuration
    echo "$updated_config" > "$config_file"
    chmod 600 "$config_file"

    log_info "Configuration updated successfully"
    return 0
}

# Get configuration field
get_configuration_field() {
    local field="$1"
    local default="${2:-}"

    local config_file="$TAILSCALE_CONF_FILE"

    if [[ ! -f "$config_file" ]]; then
        if [[ -n "$default" ]]; then
            echo "$default"
            return 0
        fi
        return "$EXIT_ENV_ERROR"
    fi

    local value
    value=$(jq -r "$field" "$config_file")

    if [[ "$value" == "null" || -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            echo "$default"
            return 0
        fi
        return "$EXIT_ENV_ERROR"
    fi

    echo "$value"
    return 0
}


collect_final_state() {
    log_info "Collecting final state..."

    local status_json
    status_json=$(get_tailscale_status true) || return 1

    local network_state
    network_state=$(collect_network_state) || return 1

    local exit_node_info
    exit_node_info=$(get_connection_info) || return 1

    save_final_state "$status_json" "$network_state" "$exit_node_info"
    return $?
}


# Export required functions
export -f save_initial_state save_final_state generate_configuration
export -f load_configuration validate_configuration update_configuration
export -f get_configuration_field collect_final_state
