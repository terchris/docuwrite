#!/bin/bash
# File: .devcontainer.extend/project-installs.sh
# Purpose: Post-creation setup script for development container
# Called after the devcontainer is created and installs the sw needed for a spesiffic project.
# So add you stuff here and they will go into your development container.

set -e

# Main execution flow
main() {
    echo "🚀 Starting project-installs setup..."

    # Version checks
    echo "🔍 Verifying installed versions..."
    check_node_version
    check_python_version
    check_powershell_version
    check_azure_cli_version
    check_npm_packages



    # Run project-specific installations
    install_project_tools

    echo "🎉 Post-creation setup complete!"
}

# Check Node.js version
check_node_version() {
    echo "Checking Node.js installation..."
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        echo "✅ Node.js is installed (version: $NODE_VERSION)"
    else
        echo "❌ Node.js is not installed"
        exit 1
    fi
}

# Check Python version
check_python_version() {
    echo "Checking Python installation..."
    if command -v python >/dev/null 2>&1; then
        PYTHON_VERSION=$(python --version)
        echo "✅ Python is installed (version: $PYTHON_VERSION)"
    else
        echo "❌ Python is not installed"
        exit 1
    fi
}

# Check PowerShell version
check_powershell_version() {
    echo "PowerShell version:"
    pwsh -Version
}

# Check Azure CLI version
check_azure_cli_version() {
    echo "Azure CLI version:"
    az version
}

# Check global npm packages versions
check_npm_packages() {
    echo "📦 Installed npm global packages:"
    npm list -g --depth=0
}




# Run project-specific installations
install_project_tools() {
    echo "🛠️ Installing project-specific tools..."

    # === ADD YOUR PROJECT-SPECIFIC INSTALLATIONS BELOW ===

    echo "📄 Installing document generation tools..."

    # Install system packages
    sudo apt-get update
    sudo apt-get install -y \
        wget \
        perl \
        pandoc \
        chromium \
        pdfgrep

    # Install global npm packages
    npm install -g mermaid-filter
    npm install -g @mermaid-js/mermaid-cli
    npm install -g mermaid @types/mermaid

    # Install TinyTeX
    echo "📚 Installing TinyTeX and LaTeX packages..."
    wget -qO- "https://yihui.org/tinytex/install-unx.sh" | sh

    # Add TinyTeX to PATH permanently
    echo 'export PATH="$HOME/.TinyTeX/bin/$(uname -m)-linux:$PATH"' >> ~/.bashrc
    # Also add it to current session
    export PATH="$HOME/.TinyTeX/bin/$(uname -m)-linux:$PATH"

    # Install additional LaTeX packages
    tlmgr install \
        fancyhdr \
        lastpage \
        parskip \
        tex-gyre \
        ulem

    echo "✅ Document generation tools installation complete!"

    # === END PROJECT-SPECIFIC INSTALLATIONS ===
}

main
