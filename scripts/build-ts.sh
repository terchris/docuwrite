#!/bin/bash
# file: scripts/build-ts.sh
# Description: Build TypeScript code (run inside dev container)

# Exit on any error
set -e

echo "=== Building TypeScript Code ==="

# Clean old build
npm run clean 2>/dev/null || true

# Install dependencies and build
npm install
npm run build

echo "=== TypeScript Build Complete ==="