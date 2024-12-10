#!/bin/bash
# file: src/cli/bash/docuwrite-wikicmd.sh
# Description:
# Generates documentation from markdown files using pandoc and other tools from docuwrite-base.
# Expects input files to be mounted at /app/input-repo and outputs to /app/output-repo.

set -euo pipefail

# Get script directory and template path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../bash/utils" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../../templates" && pwd)"

# Source utility scripts
source "$UTILS_DIR/logging.sh"
source "$UTILS_DIR/process-markdown.sh"
source "$UTILS_DIR/extract-todos.sh"

# Default paths (make configurable via environment variables)
INPUT_PATH="${INPUT_PATH:-/app/input-repo}"
OUTPUT_PATH="${OUTPUT_PATH:-/app/output-repo}"
TEMP_PATH="$OUTPUT_PATH/temp_markdown_conversion"
ORDER_FILE="$INPUT_PATH/.order"
MERGED_FILENAME="$TEMP_PATH/merged.md"
LATEX_TEMPLATE="$TEMPLATE_DIR/docuwrite-latex-template.tex"
OUTPUT_PDF_FILE="$OUTPUT_PATH/documentation.pdf"
TODO_LIST="$OUTPUT_PATH/todo-list.md"


# Function to display usage information
usage() {
    cat << EOF
DocuWrite Wiki Command - Documentation Generation

Usage: docuwrite-wikicmd [OPTIONS]

Options:
  -t, --title     Document title (optional)
  -u, --url       Document source URL (optional)
  -m, --message   Document message (optional)
  --todo-message  TODO list message (optional)
  -todo [<file>]  Generate a separate TODO file (optional)
  -h, --help      Display this help message and exit

The command expects:
- Input files mounted at: /app/input-repo
- Output directory mounted at: /app/output-repo

Example:
  docker run --rm \\
    -v ./my-repo:/app/input-repo \\
    -v ./output:/app/output-repo \\
    docuwrite docuwrite-wikicmd -t "My Documentation"

EOF
    exit 1
}

# Parse command line arguments
DOCUMENT_TITLE="Integration Documentation"
DOCUMENT_SOURCE_URL=""
DOCUMENT_MESSAGE="This PDF document is generated from the markdown files in the repository."
TODO_MESSAGE="This document contains a list of TODO:s extracted from the markdown files."
GENERATE_TODO="false"
DOCUMENT_GENERATE_TIME=$(date)

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -t|--title)
            DOCUMENT_TITLE="$2"
            shift 2
            ;;
        -u|--url)
            DOCUMENT_SOURCE_URL="$2"
            shift 2
            ;;
        -m|--message)
            DOCUMENT_MESSAGE="$2"
            shift 2
            ;;
        --todo-message)
            TODO_MESSAGE="$2"
            shift 2
            ;;
        -todo)
            GENERATE_TODO="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Validate input/output directories
if [[ ! -d "$INPUT_PATH" ]]; then
    error "Input directory not mounted at $INPUT_PATH"
fi

if [[ ! -d "$OUTPUT_PATH" ]]; then
    error "Output directory not mounted at $OUTPUT_PATH"
fi

# Cleanup and create directories
log "Cleaning up old files and creating directories"
rm -rf "$TEMP_PATH"
mkdir -p "$TEMP_PATH"

# Initialize merged Markdown file with metadata
log "Initializing merged Markdown file with document metadata"
{
    echo "% $DOCUMENT_TITLE"
    [[ -n "$DOCUMENT_SOURCE_URL" ]] && echo "% Generated from $DOCUMENT_SOURCE_URL"
    echo "% Warning: $DOCUMENT_MESSAGE Generated at $DOCUMENT_GENERATE_TIME"
    echo "\\newpage"
} > "$MERGED_FILENAME"

# Process markdown files
log "Processing Markdown files"
process_markdown_files "$INPUT_PATH" "$TEMP_PATH" "$MERGED_FILENAME" "$ORDER_FILE"

# Extract TODOs
log "Extracting TODOs"
if [ "$GENERATE_TODO" = "true" ]; then
    extract_todos "$MERGED_FILENAME" "$TODO_MESSAGE" "$DOCUMENT_GENERATE_TIME" > "$TODO_LIST"
    log "Appending TODO list to main document"
    cat "$TODO_LIST" >> "$MERGED_FILENAME"
else
    log "Skipping TODO extraction (not requested)"
fi

# Generate final PDF
log "Generating final PDF"
pandoc "$MERGED_FILENAME" \
    --pdf-engine=xelatex \
    --resource-path=. \
    --embed-resources \
    --standalone \
    --toc \
    --toc-depth=3 \
    --include-in-header="$LATEX_TEMPLATE" \
    -o "$OUTPUT_PDF_FILE" || {
        error "Pandoc PDF conversion failed"
        exit 1
    }

# Check if PDF generation was successful
if [[ -f "$OUTPUT_PDF_FILE" ]]; then
    log "PDF file generated successfully at: $OUTPUT_PDF_FILE"
    log "Cleaning up temporary files"
    rm -rf "$TEMP_PATH"
else
    log "Error: Failed to generate PDF file"
    log "Contents of $TEMP_PATH:"
    ls -la "$TEMP_PATH"
    log "Contents of $OUTPUT_PATH:"
    ls -la "$OUTPUT_PATH"
    exit 1
fi

log "Documentation generation completed successfully" 