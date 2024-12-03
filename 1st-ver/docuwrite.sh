#!/bin/bash

# File: docuwrite.sh
#
# Description: This script is the main entry point for the Bifrost DocuWrite system.
# It handles Docker operations, including building the image if necessary,
# and runs the documentation generation process.
#
# Usage: ./docuwrite.sh [build] [-i <input_repo_path>] [-d <output_document_path>] [OPTIONS]
#
# Author: [Your Name]
# Date: [Current Date]
# Version: 3.4

set -euo pipefail

DOCKER_IMAGE_NAME="terchris/bifrost-docuwrite:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Record start time
START_TIME=$(date +%s)

# Function to display usage information
usage() {
    cat << EOF
Bifrost DocuWrite - Documentation Generation System

Usage: $0 [build] [-i <input_repo_path>] [-d <output_document_path>] [OPTIONS]

Options:
  build           Build the Docker image before running (optional)
  -i, --input     Path to the input repository (required for document generation)
  -d, --document  Document name and path (optional, default: ./docuwrite-document.pdf)
  -t, --title     Document title (optional)
  -u, --url       Document source URL (optional)
  -m, --message   Document message (optional)
  --todo-message  TODO list message (optional)
  --skip-mermaid  Skip Mermaid diagram generation (optional)
  -todo [<file>]  Generate a separate TODO file (optional, default: ./todo.md)
  -h, --help      Display this help message and exit

Examples:
  $0 build
  $0 -i ./my-repo -d ./output.pdf -t "My Documentation" -todo
  $0 -i ./my-repo -d ./output.pdf --skip-mermaid

For more information, visit: https://github.com/terchris/bifrostdocuwrite

EOF
    exit 1
}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to log errors
error() {
    log "ERROR: $1" >&2
    exit 1
}

# Function to build Docker image
build_docker_image() {
    log "Building Docker image..."
    if ! docker build -t "$DOCKER_IMAGE_NAME" "$SCRIPT_DIR"; then
        error "Failed to build Docker image."
    fi
    log "Docker image built successfully."
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker and try again."
fi

# Display help if no arguments are provided
if [ $# -eq 0 ]; then
    usage
fi

# Parse command line arguments
BUILD_IMAGE=false
GENERATE_DOC=false
INPUT_REPO=""
DOCUMENT_PATH="$SCRIPT_DIR/docuwrite-document.pdf"
DOCUMENT_TITLE=""
DOCUMENT_SOURCE_URL=""
DOCUMENT_MESSAGE=""
TODO_MESSAGE=""
SKIP_MERMAID=""
GENERATE_TODO=false
TODO_FILE=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        build)
            BUILD_IMAGE=true
            shift
            ;;
        -i|--input)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "Input repository path is required after $1"
            fi
            INPUT_REPO="$2"
            GENERATE_DOC=true
            shift 2
            ;;
        -d|--document)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "Output document path is required after $1"
            fi
            DOCUMENT_PATH="$2"
            shift 2
            ;;
        -t|--title)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "Document title is required after $1"
            fi
            DOCUMENT_TITLE="$2"
            shift 2
            ;;
        -u|--url)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "Document source URL is required after $1"
            fi
            DOCUMENT_SOURCE_URL="$2"
            shift 2
            ;;
        -m|--message)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "Document message is required after $1"
            fi
            DOCUMENT_MESSAGE="$2"
            shift 2
            ;;
        --todo-message)
            if [[ $# -lt 2 || $2 == -* ]]; then
                error "TODO list message is required after $1"
            fi
            TODO_MESSAGE="$2"
            shift 2
            ;;
        --skip-mermaid)
            SKIP_MERMAID="true"
            shift
            ;;
        -todo)
            GENERATE_TODO=true
            if [[ $# -gt 1 && $2 != -* ]]; then
                TODO_FILE="$2"
                shift
            else
                TODO_FILE="$SCRIPT_DIR/todo.md"
            fi
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option $1"
            ;;
    esac
done

# Build the Docker image if requested or if it doesn't exist
if $BUILD_IMAGE || [[ "$(docker images -q $DOCKER_IMAGE_NAME 2> /dev/null)" == "" ]]; then
    build_docker_image
fi

# If we're not generating a document, exit here
if ! $GENERATE_DOC; then
    if ! $BUILD_IMAGE; then
        log "No action specified. Use 'build' to build the Docker image or provide an input repository to generate documentation."
        usage
    fi
    exit 0
fi

# Validate required input for document generation
if [[ -z "$INPUT_REPO" ]]; then
    error "Input repository is required for document generation."
fi

# Ensure the input repository exists
if [[ ! -d "$INPUT_REPO" ]]; then
    error "Input repository does not exist: $INPUT_REPO"
fi

# Create a temporary output directory
TEMP_OUTPUT_DIR=$(mktemp -d) || error "Failed to create temporary directory"

# Prepare Docker run command
DOCKER_CMD="docker run --rm"
DOCKER_CMD+=" -v \"$INPUT_REPO\":/app/input-repo"
DOCKER_CMD+=" -v \"$TEMP_OUTPUT_DIR\":/app/output-repo"

# Add optional environment variables
[[ -n "$DOCUMENT_TITLE" ]] && DOCKER_CMD+=" -e DOCUMENT_TITLE=\"$DOCUMENT_TITLE\""
[[ -n "$DOCUMENT_SOURCE_URL" ]] && DOCKER_CMD+=" -e DOCUMENT_SOURCE_URL=\"$DOCUMENT_SOURCE_URL\""
[[ -n "$DOCUMENT_MESSAGE" ]] && DOCKER_CMD+=" -e DOCUMENT_MESSAGE=\"$DOCUMENT_MESSAGE\""
[[ -n "$TODO_MESSAGE" ]] && DOCKER_CMD+=" -e TODO_MESSAGE=\"$TODO_MESSAGE\""
[[ -n "$SKIP_MERMAID" ]] && DOCKER_CMD+=" -e SKIP_MERMAID=\"$SKIP_MERMAID\""
$GENERATE_TODO && DOCKER_CMD+=" -e GENERATE_TODO=true"

# Add image name
DOCKER_CMD+=" $DOCKER_IMAGE_NAME"

# Run the Docker container
log "Starting documentation generation process..."
if ! eval "$DOCKER_CMD"; then
    error "Docker container exited with an error. Check the logs above for details."
fi

# Move the generated document to the specified location
if [[ -f "$TEMP_OUTPUT_DIR/documentation.pdf" ]]; then
    if ! mv "$TEMP_OUTPUT_DIR/documentation.pdf" "$DOCUMENT_PATH"; then
        error "Failed to move the generated PDF to $DOCUMENT_PATH"
    fi
    log "Documentation generation complete. Output file is at: $DOCUMENT_PATH"
else
    error "PDF file was not generated. Check the Docker logs for more information."
fi

# Move the generated TODO file if requested
if $GENERATE_TODO; then
    if [[ -f "$TEMP_OUTPUT_DIR/todo-list.md" ]]; then
        if ! mv "$TEMP_OUTPUT_DIR/todo-list.md" "$TODO_FILE"; then
            error "Failed to move the generated TODO file to $TODO_FILE"
        fi
        log "TODO list generation complete. Output file is at: $TODO_FILE"
    else
        log "Warning: TODO file was not generated. Check the Docker logs for more information."
    fi
fi

# Cleanup temporary directory
rm -rf "$TEMP_OUTPUT_DIR"

# Calculate and log the total execution time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log "Process completed successfully."
log "Total execution time: ${MINUTES} minutes and ${SECONDS} seconds"