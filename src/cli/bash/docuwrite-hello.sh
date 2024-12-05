#!/bin/bash
# file: src/cli/bash/docuwrite-hello.sh
# Description:
# This script executes the compiled TypeScript command for hello world.

# Exit on error
set -e

# Check if we're in development (script is in src directory) or production
if [[ "$0" == *"/src/"* ]]; then
    # Development path
    NODE_EXECUTABLE="$(pwd)/dist/cli/typescript/commands/docuwrite-hello.js"
else
    # Production path
    NODE_EXECUTABLE="/usr/local/docuwrite/cli/commands/docuwrite-hello.js"
fi

# Check if Node.js executable exists
if [ ! -f "$NODE_EXECUTABLE" ]; then
    echo "Error: Hello command not found at $NODE_EXECUTABLE"
    echo "Make sure TypeScript compilation completed successfully"
    exit 1
fi

# Check if file is executable
if [ ! -x "$NODE_EXECUTABLE" ]; then
    echo "Warning: Making hello command executable"
    chmod +x "$NODE_EXECUTABLE"
fi

# Execute the command with all passed arguments
node "$NODE_EXECUTABLE" "$@"