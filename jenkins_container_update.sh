#!/bin/bash

# Jenkins Container Update Script
# This script updates Jenkins running in a Docker container
# Usage:
#   ./jenkins_container_update.sh <container_name> <jenkins_version> [auto_restart]
# Example:
#   ./jenkins_container_update.sh jenkins-server0325 2.414.1
#   ./jenkins_container_update.sh jenkins-server0325 2.414.1 y
#   ./jenkins_container_update.sh jenkins-server0325 2.414.1 n

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if correct number of arguments provided
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    print_error "Invalid number of arguments."
    echo "Usage: $0 <container_name> <jenkins_version> [auto_restart]"
    echo "  auto_restart: 'y' or 'n' (optional, default: prompt user)"
    echo "Example: $0 jenkins-server0325 2.414.1"
    echo "         $0 jenkins-server0325 2.414.1 y"
    echo "         $0 jenkins-server0325 2.414.1 n"
    exit 1
fi

CONTAINER_NAME="$1"
NEW_VERSION="$2"
RESTART_CONTAINER_ARG="${3:-}"

# Validate version format
VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! "$NEW_VERSION" =~ $VERSION_REGEX ]]; then
    print_error "Invalid version format: $NEW_VERSION"
    echo "Version must be in format X.Y.Z (e.g., 2.414.1)"
    exit 1
fi

# Determine auto-restart behavior
RESTART_CONTAINER=false
if [[ -n "$RESTART_CONTAINER_ARG" ]]; then
    # Parameter provided, use it
    if [[ $RESTART_CONTAINER_ARG =~ ^[Yy]$ ]]; then
        RESTART_CONTAINER=true
        print_info "Container will be restarted automatically after update (from parameter)."
    elif [[ $RESTART_CONTAINER_ARG =~ ^[Nn]$ ]]; then
        RESTART_CONTAINER=false
        print_info "Container will NOT be restarted automatically (from parameter)."
    else
        print_error "Invalid auto_restart parameter: $RESTART_CONTAINER_ARG"
        echo "Must be 'y' or 'n'"
        exit 1
    fi
else
    # No parameter provided, ask user
    echo ""
    read -p "Do you want to restart the container after update? [Y/n]: " -n 1 -r RESTART_CHOICE
    echo ""
    if [[ -z "$RESTART_CHOICE" ]] || [[ $RESTART_CHOICE =~ ^[Yy]$ ]]; then
        RESTART_CONTAINER=true
        print_info "Container will be restarted automatically after update."
    else
        RESTART_CONTAINER=false
        print_info "Container will NOT be restarted automatically."
    fi
fi
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH."
    exit 1
fi

# Check if container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Container '$CONTAINER_NAME' is not running."
    echo "Available running containers:"
    docker ps --format 'table {{.Names}}\t{{.Status}}'
    exit 1
fi

print_info "Starting Jenkins update process for container: $CONTAINER_NAME"
print_info "Target version: $NEW_VERSION"

# Check if jenkins_update.sh exists
UPDATE_SCRIPT="jenkins_update.sh"
if [ ! -f "$UPDATE_SCRIPT" ]; then
    print_error "Update script '$UPDATE_SCRIPT' not found in current directory."
    exit 1
fi

# Copy update script to container
print_info "Copying update script to container..."
if ! docker cp "$UPDATE_SCRIPT" "${CONTAINER_NAME}:/tmp/jenkins_update.sh"; then
    print_error "Failed to copy update script to container."
    exit 1
fi

# Execute update script inside container
print_info "Executing update script inside container..."
echo "----------------------------------------"
if docker exec -it --user root -e VERSION="$NEW_VERSION" "$CONTAINER_NAME" \
    bash -c "/tmp/jenkins_update.sh"; then
    UPDATE_SUCCESS=true
else
    UPDATE_SUCCESS=false
fi
echo "----------------------------------------"

# Check if update was successful
if [ "$UPDATE_SUCCESS" = true ]; then
    print_info "Update script completed successfully."

    # Restart container if user agreed earlier
    if [ "$RESTART_CONTAINER" = true ]; then
        print_info "Restarting container: $CONTAINER_NAME"

        # Record restart time to filter logs
        RESTART_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        if docker restart "$CONTAINER_NAME"; then
            print_info "Container restarted successfully."
            print_info "Waiting for Jenkins to become ready..."

            # Wait for Jenkins to start by monitoring logs
            JENKINS_READY=false
            MAX_WAIT_TIME=120  # Maximum wait time in seconds
            ELAPSED_TIME=0
            CHECK_INTERVAL=5

            while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
                # Check for "Jenkins is fully up and running" in logs since restart
                if docker logs --since "$RESTART_TIME" -n 50 "$CONTAINER_NAME" 2>&1 | \
                   grep -q "Jenkins is fully up and running"; then
                    JENKINS_READY=true
                    break
                fi

                echo -n "."
                sleep $CHECK_INTERVAL
                ELAPSED_TIME=$((ELAPSED_TIME + CHECK_INTERVAL))
            done
            echo ""

            if [ "$JENKINS_READY" = true ]; then
                print_info "✓ Jenkins is fully up and running (waited ${ELAPSED_TIME}s)"

                # Verify new version
                print_info "Verifying Jenkins version..."
                ACTUAL_VERSION=$(docker exec "$CONTAINER_NAME" \
                    java -jar /usr/share/jenkins/jenkins.war --version 2>/dev/null || echo "unknown")

                if [ "$ACTUAL_VERSION" = "$NEW_VERSION" ]; then
                    print_info "✓ Jenkins successfully updated to version $ACTUAL_VERSION"
                else
                    print_warning "Jenkins version is $ACTUAL_VERSION (expected $NEW_VERSION)"
                fi
            else
                print_warning "Jenkins did not become ready within ${MAX_WAIT_TIME}s"
                print_warning "Please check container logs: docker logs $CONTAINER_NAME"
            fi
        else
            print_error "Failed to restart container."
            exit 1
        fi
    else
        print_warning "Container not restarted. Please restart manually:"
        echo "  docker restart $CONTAINER_NAME"
    fi
else
    print_error "Update script failed. Please check the error messages above."
    exit 1
fi

print_info "Update process completed."
