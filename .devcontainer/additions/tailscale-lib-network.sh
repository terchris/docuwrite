#!/bin/bash
# File: .devcontainer/additions/tailscale-lib-network.sh
#
# Purpose:
#   Provides comprehensive network testing, tracing, and connectivity verification.
#   Handles both pre-Tailscale and post-Tailscale network state analysis.
#
# Functions:
#   - Network state verification
#   - Connectivity testing
#   - Route tracing
#   - Network state collection
#
# Dependencies:
#   - tailscale-lib-common.sh : Common utilities and logging
#   - Required tools: ping, traceroute, ip, nc, host
#
# Author: Terje Christensen
# Created: November 2024

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly"
    exit 1
fi

# Network test configuration
readonly DEFAULT_PING_COUNT=4
readonly DEFAULT_PING_TIMEOUT=5
readonly DEFAULT_TRACE_HOPS=10
readonly DEFAULT_TRACE_TIMEOUT=2
readonly DEFAULT_TEST_DOMAIN="www.sol.no"
readonly DEFAULT_DNS_SERVERS=(
    "8.8.8.8"      # Google DNS
    "1.1.1.1"      # Cloudflare DNS
    "208.67.222.222" # OpenDNS
)

# Primary network testing function that encompasses all checks
verify_network_state() {
    local test_type="$1"  # basic, full, or pre-tailscale
    local options="${2:-}"

    log_info "Verifying network state (type: ${test_type})"

    case "$test_type" in
        basic)
            check_basic_connectivity
            ;;
        full)
            check_basic_connectivity && \
            check_udp_connectivity && \
            check_network_interfaces
            ;;
        pre-tailscale)
            check_basic_connectivity && \
            check_udp_connectivity && \
            verify_tun_device && \
            check_network_interfaces
            ;;
        *)
            log_error "Unknown test type: $test_type"
            return "$EXIT_NETWORK_ERROR"
            ;;
    esac
}

# Check basic internet connectivity
# Check basic internet connectivity
check_basic_connectivity() {
   local target="${1:-${DEFAULT_DNS_SERVERS[0]}}"
   local timeout="${2:-$DEFAULT_PING_TIMEOUT}"
   local attempts="${3:-3}"

   log_info "Checking basic connectivity to $target..."

   # Use timeout command to ensure we don't hang
   local ping_cmd="ping -c 1 -W $timeout $target"
   local attempt=1
   local last_error=""

   while ((attempt <= attempts)); do
       if output=$(timeout $((timeout + 1)) $ping_cmd 2>&1); then
           local rtt
           rtt=$(echo "$output" | grep -oP 'time=\K[0-9.]+')
           log_info "Basic connectivity test successful to $target (RTT: ${rtt}ms)"
           return 0
       else
           local exit_code=$?
           last_error=$(echo "$output" | tr -d '\n')

           case $exit_code in
               124|137) # timeout command exit codes
                   log_debug "Attempt $attempt to $target: Connection timed out"
                   ;;
               2) # Host unreachable
                   log_debug "Attempt $attempt to $target: Host unreachable"
                   ;;
               *)
                   log_debug "Attempt $attempt to $target: Ping failed with code $exit_code"
                   ;;
           esac
       fi

       # Only sleep if we're going to try again
       if ((attempt < attempts)); then
           sleep 1
       fi
       attempt=$((attempt + 1))
   done

   log_error "Failed to establish basic connectivity to $target after $attempts attempts"
   log_error "Last error: $last_error"
   return "$EXIT_NETWORK_ERROR"
}

# Check UDP connectivity
check_udp_connectivity() {
    local port="${1:-53}"
    local target="${2:-${DEFAULT_DNS_SERVERS[0]}}"
    local attempts="${3:-3}"

    log_info "Testing UDP connectivity to $target:$port..."

    # Ensure netcat is available
    if ! command -v nc >/dev/null; then
        log_error "netcat (nc) not found, installing..."
        if ! apt-get update -qq && apt-get install -y netcat-openbsd >/dev/null 2>&1; then
            log_error "Failed to install netcat"
            return "$EXIT_NETWORK_ERROR"
        fi
    fi

    local attempt=1
    while ((attempt <= attempts)); do
        if nc -zu "$target" "$port" -w 1 >/dev/null 2>&1; then
            log_info "UDP connectivity test successful"
            return 0
        fi
        log_debug "UDP connectivity attempt $attempt failed, retrying..."
        attempt=$((attempt + 1))
        sleep 1
    done

    log_warn "UDP connectivity might be restricted"
    return 1
}

# Verify TUN device
verify_tun_device() {
    log_info "Verifying TUN device..."

    if [[ ! -c /dev/net/tun ]]; then
        log_error "TUN device not found at /dev/net/tun"
        return "$EXIT_NETWORK_ERROR"
    fi

    # Check permissions
    local tun_perms
    tun_perms=$(stat -c "%a" /dev/net/tun)
    if [[ "$tun_perms" != "666" && "$tun_perms" != "660" ]]; then
        log_warn "TUN device has unexpected permissions: $tun_perms"
    fi

    log_info "TUN device verification successful"
    return 0
}

# Check network interfaces
check_network_interfaces() {
    log_info "Checking network interfaces..."

    # Get default route interface
    local default_if
    default_if=$(ip route show default | awk '/default/ {print $5}')
    if [[ -z "$default_if" ]]; then
        log_error "No default route interface found"
        return "$EXIT_NETWORK_ERROR"
    fi

    # Check interface state
    local if_state
    if_state=$(ip link show "$default_if" | grep -o "state [A-Z]*" | cut -d' ' -f2)
    if [[ "$if_state" != "UP" ]]; then
        log_error "Default interface $default_if is not UP (state: $if_state)"
        return "$EXIT_NETWORK_ERROR"
    fi

    # Get interface addresses
    local if_addrs
    if_addrs=$(ip addr show "$default_if" | grep -w inet)
    if [[ -z "$if_addrs" ]]; then
        log_error "No IPv4 addresses found on default interface $default_if"
        return "$EXIT_NETWORK_ERROR"
    fi

    log_info "Network interface check successful"
    log_debug "Default interface: $default_if ($if_state)"
    return 0
}

# Collect network interface information
collect_interface_info() {
    local interface="$1"
    log_info "Collecting interface information for $interface..."

    jq -n \
        --arg name "$interface" \
        --arg state "$(ip link show "$interface" | grep -o 'state [A-Z]*' | cut -d' ' -f2)" \
        --arg addrs "$(ip addr show "$interface" | grep -w inet | awk '{print $2}')" \
        --arg flags "$(ip link show "$interface" | grep -o 'FLAGS.*' | cut -d' ' -f1)" \
        '{
            name: $name,
            state: $state,
            addresses: ($addrs | split("\n") | map(select(length > 0))),
            flags: $flags,
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }'
}


# Collect route information
collect_route_info() {
    log_info "Collecting routing information..."

    # Create a JSON array of routes manually since ip -j may not be available
    local routes
    routes=$(ip route show | jq -R -s 'split("\n") | map(select(length > 0))')

    jq -n \
        --argjson routes "$routes" \
        '{
            routes: $routes,
            default: ($routes | map(select(contains("default"))) | .[0] // null),
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }'
}

# Collect complete network state
collect_network_state() {
   log_info "Collecting complete network state..."

   # Use jc for cleaner JSON output
   local interfaces_json
   interfaces_json=$(ifconfig | jc --ifconfig)

   local routes_json
   routes_json=$(route -n | jc --route)

   # Get default interface
   local default_if
   default_if=$(route -n | awk '$1=="0.0.0.0" {print $8}')

   # Combine all information
   jq -n \
       --arg defif "$default_if" \
       --argjson interfaces "$interfaces_json" \
       --argjson routes "$routes_json" \
       '{
           timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
           defaultInterface: $defif,
           interfaces: $interfaces,
           routes: $routes,
           state: {
               basic_connectivity: null,
               dns_resolution: null,
               udp_connectivity: null
           }
       }'

   return 0
}

# Trace route to target
trace_route() {
    local target="${1:-$DEFAULT_TEST_DOMAIN}"
    local max_hops=10
    local timeout=2

    log_info "Tracing route to $target..."
    local result=$(traceroute -w "$timeout" -m "$max_hops" "$target" 2>/dev/null | jc --traceroute)
    local hop_count=$(echo "$result" | jq '.hops | length')
    log_info "Found $hop_count hops"
    echo "$result" | jq -c '.'  # Use -c for compact output if needed internally
}




# Add to tailscale-lib-network.sh

# Collects the initial network state before Tailscale configuration.
# Creates the networkState.initial section of tailscale.conf.
#
# Input:
#   None - Uses environment variables for test URLs and configurations
#
# Output:
#   stdout: JSON object containing:
#     - timestamp: When the state was collected
#     - testDNS: DNS resolution test results
#     - testUrl: URL connectivity test results
#     - traceroute: Detailed path analysis to test URL
#
# Returns:
#   0 (EXIT_SUCCESS): Successfully collected state
#   2 (EXIT_NETWORK_ERROR): Failed to collect state
#
collect_initial_state() {
    log_info "Collecting initial network state..."

    # Test URL connectivity first
    local target="${TAILSCALE_TEST_URL:-www.sol.no}"
    local url_test_result
    url_test_result=$(check_basic_connectivity "$target" | jq -n --arg host "$target" --arg reachable "true" --arg latency "0" '{
        host: $host,
        reachable: $reachable,
        latency: ($latency | tonumber)
    }')

    # Get trace information
    local trace_info
    trace_info=$(trace_route "$target")

    # Create complete state
    local initial_state
    initial_state=$(jq -n \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --argjson url "$url_test_result" \
        --argjson trace "$trace_info" \
        '{
            timestamp: $timestamp,
            testUrl: $url,
            traceroute: $trace
        }')

    echo "$initial_state" > "${TAILSCALE_STATE_DIR}/initial_state.json"
    return "$EXIT_SUCCESS"
}

# Start Tailscale daemon
start_tailscale_daemon() {
    log_info "Checking Tailscale daemon status..."

    if pidof tailscaled >/dev/null; then
        log_info "Stopping existing Tailscale daemon..."
        pkill tailscaled || true
        sleep 2
    fi

    log_info "Starting Tailscale daemon..."
    # Redirect verbose output to log file
    tailscaled --verbose=1 --statedir="${TAILSCALE_STATE_DIR}" > "${TAILSCALE_DAEMON_LOG}" 2>&1 &

    local retries=5
    while ((retries > 0)); do
        if pidof tailscaled >/dev/null; then
            log_info "Daemon started successfully"
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    log_error "Failed to start Tailscale daemon"
    return 1
}

stop_tailscale_daemon() {
    # First stop any existing daemon
    log_info "Checking Tailscale daemon status..."
    if pidof tailscaled >/dev/null; then
        log_info "Stopping existing Tailscale daemon..."
        pkill tailscaled || true
        sleep 2
    fi
    return 0
}


establish_tailscale_connection() {
    local hostname="${1:-}"

    # Validate input
    if [[ -z "$hostname" ]]; then
        log_error "hostname parameter is required"
        return 1
    fi

    local max_retries=3
    local retry_count=0
    local connected=false

    log_info "Connecting to Tailscale network as '${hostname}'..."

    # Check existing connections and clean up if needed
    if tailscale status >/dev/null 2>&1; then
        log_info "Found existing Tailscale connection, logging out..."
        tailscale logout
        sleep 2
    fi

    # Attempt connection with retries
    while ((retry_count < max_retries)) && [[ "$connected" != "true" ]]; do
        retry_count=$((retry_count + 1))

        # Force the hostname we want
        if ! tailscale up --reset --force-reauth --hostname="$hostname"; then
            log_error "Connection attempt ${retry_count} failed"
            sleep 2
            continue
        fi

        # Wait for connection to stabilize
        sleep 3

        # Verify connection and hostname
        local status_json
        if ! status_json=$(tailscale status --json); then
            log_error "Failed to get Tailscale status"
            continue
        fi

        # Check if we're actually connected
        if ! echo "$status_json" | jq -e '.BackendState == "Running"' >/dev/null; then
            log_error "Tailscale backend is not running"
            continue
        fi

        # Verify hostname
        local assigned_hostname
        assigned_hostname=$(echo "$status_json" | jq -r '.Self.HostName')
        if [[ "$assigned_hostname" != "$hostname" ]]; then
            log_error "Got unexpected hostname: $assigned_hostname (wanted: $hostname)"
            continue
        fi

        # Get our assigned IP
        local ip
        ip=$(echo "$status_json" | jq -r '.Self.TailscaleIPs[0]')
        if [[ -z "$ip" || "$ip" == "null" ]]; then
            log_error "No Tailscale IP assigned"
            continue
        fi

        log_info "Connected successfully as '${hostname}' with IP: ${ip}"
        connected=true


    done

    if [[ "$connected" != "true" ]]; then
        log_error "Failed to establish connection after ${max_retries} attempts"
        return 1
    fi

    return 0
}


# Export required functions
export -f verify_network_state check_basic_connectivity
export -f check_udp_connectivity verify_tun_device check_network_interfaces
export -f collect_interface_info collect_route_info collect_network_state
export -f trace_route collect_initial_state start_tailscale_daemon stop_tailscale_daemon establish_tailscale_connection
