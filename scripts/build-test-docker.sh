#!/bin/bash
# file: scripts/build-test-docker.sh
# Description: Build and test Docker container (run on host)

# Exit on any error
set -e

echo "=== Building and Testing DocuWrite Container ==="

# Step 1: Build Docker Container
echo -e "\nBuilding Docker container..."
docker build -t docuwrite -f docker/Dockerfile.prod .

# Step 2: Test Container
echo -e "\n=== Running Tests ==="

echo -e "\nTest 1: Help Command"
echo "Running: docker run --rm docuwrite help"
# Redirect stderr to hide the "Unknown tool" error
docker run --rm docuwrite help 2>/dev/null

echo -e "\nTest 2: Command-specific Help"
echo "Running: docker run --rm docuwrite docuwrite-hello --help"
docker run --rm docuwrite docuwrite-hello --help

echo -e "\nTest 3: Basic Hello Command"
echo "Running: docker run --rm docuwrite docuwrite-hello"
docker run --rm docuwrite docuwrite-hello

echo -e "\nTest 4: Verbose Hello Command"
echo "Running: docker run --rm docuwrite docuwrite-hello --verbose"
docker run --rm docuwrite docuwrite-hello --verbose

echo -e "\nTest 5: Verify Base Command (pandoc version)"
echo "Running: docker run --rm docuwrite pandoc --version | head -n 1"
docker run --rm docuwrite pandoc --version | head -n 1

echo -e "\nTest 6: Pandoc Help"
echo "Running: docker run --rm docuwrite pandoc --help | head -n 5"
# Use 'sed' to remove the broken pipe error
docker run --rm docuwrite pandoc --help 2>/dev/null | head -n 5 | sed '/broken pipe/d'

echo -e "\nTest 7: Running Base Container Tests"
echo "Running: docker run --rm docuwrite test-install"
docker run --rm docuwrite test-install

echo -e "\n=== All Tests Completed Successfully ==="