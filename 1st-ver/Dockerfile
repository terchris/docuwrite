# File: Dockerfile
#
# Description: This Dockerfile sets up the environment for the Bifrost DocuWrite system.
# It uses a Node.js base image, installs TinyTeX for a non-root user, and includes necessary
# LaTeX packages and tools for document generation. This version is optimized for ARM64 architecture
# and includes a non-root user for running the application.
#
# Author: [Your Name]
# Date: [Current Date]
# Version: 3.0

# Use an official Node.js image as the base
FROM node:14-bullseye-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary tools and dependencies
RUN apt-get update && apt-get install -y \
    wget \
    perl \
    pandoc \
    chromium \
    pdfgrep \
    && rm -rf /var/lib/apt/lists/*

# Set environment variable to skip Puppeteer download
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Create a non-root user for running the application
RUN useradd -m docuser

# Switch to the non-root user
USER docuser
WORKDIR /home/docuser

# Set up npm global directory for the user
ENV NPM_CONFIG_PREFIX=/home/docuser/.npm-global
ENV PATH="/home/docuser/.npm-global/bin:$PATH"

# Install mermaid-filter globally for the user
RUN mkdir -p /home/docuser/.npm-global && \
    npm install -g mermaid-filter

# Install mermaid-cli
RUN npm install -g @mermaid-js/mermaid-cli

# Install mermaid and its type definitions
RUN npm install -g mermaid @types/mermaid

# Set up TinyTeX for the non-root user
ENV PATH="/home/docuser/.TinyTeX/bin/aarch64-linux:$PATH"

RUN wget -qO- "https://yihui.org/tinytex/install-unx.sh" | sh \
    && ~/.TinyTeX/bin/*/tlmgr path add \
    && tlmgr update --self --all \
    && tlmgr install \
    xetex \
    luatex \
    latex-bin \
    tex-gyre \
    amsfonts \
    amsmath \
    latex-amsmath-dev \
    latexmk \
    fancyhdr \
    lastpage \
    geometry \
    graphics \
    tools \
    babel \
    hyperref \
    parskip \
    ulem \
    xcolor

# Set working directory for the container
WORKDIR /app

# Copy the bash script into the container
COPY --chown=docuser:docuser builddoc.sh /app/builddoc.sh

# Make sure the script is executable
RUN chmod +x /app/builddoc.sh

# Set the entrypoint to the bash script
ENTRYPOINT ["/app/builddoc.sh"]
