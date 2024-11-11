# Start with Python 3.11 image based on Debian 12 (Bookworm)
FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/python:1-3.11-bookworm

# Create and set permissions for VS Code directories
RUN mkdir -p /home/vscode/.vscode-server/extensions \
    /home/vscode/.vscode-server/data \
    /home/vscode/.vscode-server/bin && \
    chown -R vscode:vscode /home/vscode/.vscode-server

# Switch back to the vscode user for security
USER vscode
