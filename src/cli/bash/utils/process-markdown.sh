#!/bin/bash
# shellcheck disable=SC1091
# file: src/cli/bash/utils/process-markdown.sh
# Description: Functions for processing markdown files in DocuWrite

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging utilities
source "$SCRIPT_DIR/logging.sh"

# Function to process a single markdown file
# Arguments:
#   $1 - Input file path
#   $2 - Temporary directory
#   $3 - Output file to append to
process_single_file() {
    local input_file="$1"
    local temp_dir="$2"
    local output_file="$3"
    local basename_file
    local temp_processed_file
    
    basename_file=$(basename "$input_file")
    temp_processed_file="$temp_dir/$basename_file"
    
    log "Processing file: $basename_file"
    
    # Process markdown with Mermaid diagrams using mmdc
    mmdc -i "$input_file" \
         -o "$temp_processed_file" \
         --pdfFit \
         --outputFormat png \
         --puppeteerConfigFile "${PUPPETEER_CONFIG:-/etc/puppeteer/config.json}" || {
        warn "Mermaid processing failed for $basename_file"
        # Fallback to copying the original file if mermaid processing fails
        cp "$input_file" "$temp_processed_file"
    }
    
    # Change working directory to temp_dir for processing
    cd "$temp_dir" || exit 1
    
    cat "$temp_processed_file" >> "$output_file"
    echo -e '\n\\newpage\n' >> "$output_file"
}

# Function to process markdown files according to .order file
# Arguments:
#   $1 - Input directory
#   $2 - Temporary directory
#   $3 - Output merged file
#   $4 - Order file path
process_ordered_files() {
    local input_dir="$1"
    local temp_dir="$2"
    local output_file="$3"
    local order_file="$4"

    log "Found .order file, processing files in specified order"
    while IFS= read -r file || [[ -n "$file" ]]; do
        file=$(echo "$file" | tr -d ' "' | tr -d '\r')
        if [[ -f "$input_dir/$file" ]]; then
            process_single_file "$input_dir/$file" "$temp_dir" "$output_file"
        else
            warn "File '$file' listed in $order_file does not exist"
        fi
    done < "$order_file"
}

# Function to process all markdown files in a directory
# Arguments:
#   $1 - Input directory
#   $2 - Temporary directory
#   $3 - Output merged file
process_all_files() {
    local input_dir="$1"
    local temp_dir="$2"
    local output_file="$3"

    log "Processing all .md files in alphabetical order"
    for file in "$input_dir"/*.md; do
        if [[ -f "$file" ]]; then
            process_single_file "$file" "$temp_dir" "$output_file"
        fi
    done
}

# Main function to process markdown files
# Arguments:
#   $1 - Input directory
#   $2 - Temporary directory
#   $3 - Output merged file
#   $4 - Order file path
process_markdown_files() {
    local input_dir="$1"
    local temp_dir="$2"
    local output_file="$3"
    local order_file="$4"

    if [[ -f "$order_file" ]]; then
        process_ordered_files "$input_dir" "$temp_dir" "$output_file" "$order_file"
    else
        warn ".order file not found. Processing all .md files in alphabetical order."
        process_all_files "$input_dir" "$temp_dir" "$output_file"
    fi
} 