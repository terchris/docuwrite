#!/bin/bash
# file: docker/docuwrite-entrypoint.sh
# Description: Entrypoint script that preserves base functionality and adds extensions 

# Define critical paths
DOCKER_ENTRYPOINT="/usr/local/bin/docker-entrypoint"
HELLO_CMD="/usr/local/docuwrite/cli/commands/docuwrite-hello.js"

# List of our extended commands and their descriptions
# Add new commands here - this is the only place that needs updating
declare -A DOCUWRITE_COMMANDS
DOCUWRITE_COMMANDS=(
    ["docuwrite-hello"]="Test command that outputs hello"
)

# Function to show help that combines base help with our extensions
show_help() {
    {
        # Run base help and capture both stdout and stderr
        "$DOCKER_ENTRYPOINT" --help 2>&1 || true
    } | {
        # Process the output
        sed -e '/^Error: Unknown tool/d' \
            -e 's/docuwrite-base/docuwrite/g' |
        awk -v cmds="$(
            # Pass our commands to awk
            for cmd in "${!DOCUWRITE_COMMANDS[@]}"; do 
                echo "$cmd:${DOCUWRITE_COMMANDS[$cmd]}"
            done
        )" '
            BEGIN { 
                output = ""
                in_notes = 0
                # Process commands array
                split(cmds, cmd_lines, "\n")
                for (i in cmd_lines) {
                    split(cmd_lines[i], parts, ":")
                    if (parts[1] != "") {
                        commands[parts[1]] = parts[2]
                    }
                }
            }
            
            # When we hit Notes section, switch mode
            /^Notes:/ { in_notes = 1 }
            
            # Store everything as we go
            { 
                if (in_notes) {
                    notes = notes $0 "\n"
                } else {
                    output = output $0 "\n"
                }
            }
            
            END {
                # Print main content
                printf "%s", output

                # Print our extensions
                printf "\nExtended commands:\n"
                for (cmd in commands) {
                    printf "  %-15s %s\n", cmd, commands[cmd]
                }
                printf "\nFor command-specific help, use: <command> --help\n"
                printf "Example: docuwrite-hello --help\n\n"

                # Print notes section if we found it
                if (notes != "") {
                    printf "%s", notes
                }
            }
        '
    }
}

# Function to show command-specific help
show_command_help() {
    local command=$1
    case $command in
        docuwrite-hello)
            echo "docuwrite-hello - ${DOCUWRITE_COMMANDS[$command]}"
            echo "Usage: docuwrite-hello [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v   Show additional system information"
            ;;
    esac
}

# Main command handling
case "$1" in
    help|--help|-h)
        # Handle help command first
        show_help
        exit 0
        ;;
    docuwrite-*)
        # Handle our extended commands
        case "$1" in
            docuwrite-hello)
                case "$2" in
                    --help|-h)
                        show_command_help "$1"
                        exit 0
                        ;;
                    *)
                        if [ ! -f "$HELLO_CMD" ]; then
                            echo "Error: $HELLO_CMD not found" >&2
                            exit 1
                        fi
                        exec node "$HELLO_CMD" "${@:2}"
                        ;;
                esac
                ;;
            *)
                # Unknown docuwrite-* command
                show_help
                exit 0
                ;;
        esac
        ;;
    *)
        # Pass everything else to the base container
        exec "$DOCKER_ENTRYPOINT" "$@"
        ;;
esac