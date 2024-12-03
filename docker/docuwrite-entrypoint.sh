#!/bin/bash

# First, check if this is a base command (pandoc, mmdc, marp)
case "$1" in
    pandoc|mmdc|marp|test-install|bash)
        # Execute the original entrypoint for base commands
        exec /usr/local/bin/docker-entrypoint "$@"
        ;;
esac

# If we get here, check for our extended commands
case "$1" in
    # Add your new commands here
    docuwrite-*)
        # Execute our custom commands
        exec "$@"
        ;;
    help|--help|-h)
        echo "DocuWrite - Extended document processing tools"
        echo ""
        echo "Base commands (from docuwrite-base):"
        echo "  pandoc - Pandoc document converter"
        echo "  mmdc   - Mermaid CLI diagram generator"
        echo "  marp   - Marp slide deck converter"
        echo "  test-install - Run container integration tests"
        echo "  bash   - Start an interactive shell session"
        echo ""
        echo "Extended commands:"
        # Add your new commands here
        echo "  docuwrite-* - Custom document processing tools"
        echo ""
        echo "For more information about base commands, run: docker-entrypoint"
        echo "For more information about extended commands, run: docuwrite-help"
        exit 0
        ;;
    *)
        # If no command matches, show help and pass to original entrypoint
        /usr/local/bin/docker-entrypoint "$@"
        ;;
esac