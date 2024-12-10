#!/bin/bash
# file: src/cli/bash/utils/extract-todos.sh
# Description: Extracts TODO items from markdown files and formats them into a table

# Function to extract TODOs from a markdown file and output as markdown table
# Arguments:
#   $1 - Input markdown file
#   $2 - TODO message
#   $3 - Generation time
extract_todos() {
    local input_file="$1"
    local todo_message="$2"
    local generate_time="$3"

    # Header
    echo "# Generated list of TODO:s"
    echo -e "\nWarning: $todo_message Generated at $generate_time\n"
    echo "| Section | TODO Item |"
    echo "|---------|-----------|"

    # Extract TODOs with their sections
    awk '
        /^#/ {
            heading = $0; 
            gsub(/^#+ */, "", heading);
        }
        /^TODO:/ {
            if (heading != "") {
                print "| " heading " | " $0 " |";
                heading = "";
            } else {
                print "| (No heading) | " $0 " |";
            }
        }
    ' "$input_file"
} 