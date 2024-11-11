FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

# Add your standard configurations here
RUN apt-get update && apt-get install -y \
    git \
    wget

# Include extend Dockerfile if it exists
COPY ../Dockerfile.extend* /tmp/
RUN if [ -f "/tmp/Dockerfile.extend" ]; then \
    cat /tmp/Dockerfile.extend >> /dockerfile-extend && \
    bash /dockerfile-extend; \
    fi