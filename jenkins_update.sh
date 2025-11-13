#!/bin/bash

# update Jenkins war
# Usage:
#   VERSION=<target_version> ./jenkins_update.sh
#   docker exec -it --user root -e VERSION=2.414.1 jenkins-server0325 \
#   bash -c "/tmp/jenkins_update.sh"

# check I am root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

VERSION="${VERSION:-}"
# VERSION must be provided
if [ -z "$VERSION" ]; then
    echo "Error: VERSION environment variable is not set." >&2
    exit 1
fi

# check current jenkins version
CURRENT_VERSION=$(
    java -jar /usr/share/jenkins/jenkins.war --version 2>/dev/null || \
    echo "unknown"
)
echo "Current Jenkins version: $CURRENT_VERSION"

validate_and_compare_versions() {
    local version1="$1"
    local version2="$2"
    local sorted_first

    # Regular expression to validate version format (e.g., 2.123.4)
    local version_regex='^[0-9]+\.[0-9]+\.[0-9]+$'

    # Validate version1
    if [[ ! "$version1" =~ $version_regex ]]; then
        echo "Error: Version '$version1' is not in a valid format." >&2
        return 3  # Invalid version format
    fi

    # Validate version2
    if [[ ! "$version2" =~ $version_regex ]]; then
        echo "Error: Version '$version2' is not in a valid format." >&2
        return 3  # Invalid version format
    fi

    # Compare versions
    sorted_first=$(printf '%s\n' "$version1" "$version2" | \
                   sort -V | head -n 1)

    if [ "$sorted_first" == "$version1" ]; then
        if [ "$version1" == "$version2" ]; then
            return 0  # equal
        else
            return 1  # version1 < version2
        fi
    else
        return 2  # version1 > version2
    fi
}

validate_and_compare_versions "$CURRENT_VERSION" "$VERSION"
cmp_result=$?
if [ $cmp_result -eq 0 ]; then
    echo "Jenkins is already at version $VERSION. No update needed."
    exit 0
elif [ $cmp_result -eq 2 ]; then
    echo "Current Jenkins version $CURRENT_VERSION is newer than" \
         "target version $VERSION. No update performed."
    exit 0
elif [ $cmp_result -eq 3 ]; then
    echo "Error: Invalid version format detected. Please ensure both" \
         "current and target versions are in the format X.Y.Z." >&2
    exit 1
fi

JENKINS_WAR_PATH="/usr/share/jenkins/jenkins.war"
BACKUP_WAR_PATH="/usr/share/jenkins/jenkins.war.bak"
NEW_WAR_URL="https://get.jenkins.io/war-stable/${VERSION}/jenkins.war"

# Backup existing jenkins.war
if [ -f "$JENKINS_WAR_PATH" ]; then
    echo "Backing up existing jenkins.war to jenkins.war.bak"
    cp -v "$JENKINS_WAR_PATH" "$BACKUP_WAR_PATH"
else
    echo "No existing jenkins.war found, skipping backup."
fi
# Download new jenkins.war
echo "Downloading Jenkins version $VERSION from $NEW_WAR_URL"
if curl -fSL -o "$JENKINS_WAR_PATH" "$NEW_WAR_URL"; then
    echo "Successfully downloaded Jenkins version $VERSION" \
         "to $JENKINS_WAR_PATH"
else
    echo "Error: Failed to download Jenkins version $VERSION." >&2
    # Restore backup if download fails
    if [ -f "$BACKUP_WAR_PATH" ]; then
        echo "Restoring backup jenkins.war from jenkins.war.bak"
        cp -v "$BACKUP_WAR_PATH" "$JENKINS_WAR_PATH"
    fi
    exit 1
fi

# Please restart the Jenkins container for changes to take effect
echo ""
echo "Jenkins has been updated to version $VERSION."
echo "Please restart the Jenkins container for changes to take effect:"
echo "  docker restart <container_name>"