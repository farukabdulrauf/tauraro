#!/bin/bash

echo "🚀 Starting Tauraro Smart Installer with Cleanup..."

# Update Termux
echo "📦 Updating Termux..."
pkg upgrade -y && pkg update -y || echo "⚠️ Package update completed with warnings."

echo "🔍 Checking latest Tauraro version from GitHub..."

# Get latest release info with error handling
API_RESPONSE=$(curl -s -f -L --connect-timeout 10 --max-time 20 https://api.github.com/repos/tauraro/tauraro/releases/latest)

if [ $? -ne 0 ] || [ -z "$API_RESPONSE" ]; then
    echo "❌ Failed to connect to GitHub. Using fallback v0.0.3"
    LATEST_TAG="v0.0.3"
    LATEST_URL="https://github.com/tauraro/tauraro/releases/download/v0.0.3/tauraroc-linux-arm64.zip"
else
    LATEST_TAG=$(echo "$API_RESPONSE" | grep '"tag_name"' | cut -d '"' -f 4)
    LATEST_URL=$(echo "$API_RESPONSE" | grep "browser_download_url.*linux-arm64.zip" | cut -d '"' -f 4)
    
    if [ -z "$LATEST_TAG" ] || [ -z "$LATEST_URL" ]; then
        echo "⚠️ Failed to parse release info. Using fallback."
        LATEST_TAG="v0.0.3"
        LATEST_URL="https://github.com/tauraro/tauraro/releases/download/v0.0.3/tauraroc-linux-arm64.zip"
    fi
fi

echo "Latest version : $LATEST_TAG"

ZIP_FILE="tauraroc-linux-arm64.zip"

# Semantic Version Comparison
version_compare() {
    local v1=$(echo "$1" | tr -d 'vV')
    local v2=$(echo "$2" | tr -d 'vV')
    IFS='.' read -ra VER1 <<< "$v1"
    IFS='.' read -ra VER2 <<< "$v2"
    local i=0
    while [[ ${VER1[i]} || ${VER2[i]} ]]; do
        local num1=${VER1[i]:-0}
        local num2=${VER2[i]:-0}
        if (( num1 > num2 )); then return 1; fi
        if (( num1 < num2 )); then return 2; fi
        ((i++))
    done
    return 0
}

# Check current version
CURRENT_VERSION="none"
if command -v tauraroc &> /dev/null; then
    CURRENT_VERSION=$(tauraroc --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
    echo "Current version : $CURRENT_VERSION"
else
    echo "No previous installation found."
fi

# Decide whether to download
SHOULD_DOWNLOAD=true
if [ "$CURRENT_VERSION" != "none" ] && [ "$CURRENT_VERSION" != "unknown" ]; then
    version_compare "$CURRENT_VERSION" "$LATEST_TAG"
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "✅ Already on latest version."
        SHOULD_DOWNLOAD=false
    elif [ $RESULT -eq 1 ]; then
        echo "🎉 You have a newer version than GitHub."
        SHOULD_DOWNLOAD=false
    else
        echo "📦 New version available. Updating..."
    fi
fi

# Download
if [ "$SHOULD_DOWNLOAD" = true ]; then
    echo "📥 Downloading $LATEST_TAG ..."
    if ! curl -L -f --connect-timeout 15 --max-time 60 -# -o "$ZIP_FILE" "$LATEST_URL"; then
        echo "❌ Download failed!"
        exit 1
    fi
    echo "✅ Download completed."
fi

# Cleanup old installation (optional but recommended for clean update)
echo "🧹 Cleaning old files..."
rm -rf tauraro_old 2>/dev/null
if [ -d "tauraro" ]; then
    echo "Backing up old version to tauraro_old..."
    mv tauraro tauraro_old
fi

# Extract
echo "📦 Extracting new version..."
if ! unzip -o "$ZIP_FILE" -d tauraro; then
    echo "❌ Extraction failed!"
    exit 1
fi

# Automatic Cleanup: Remove zip file after successful extraction
echo "🧹 Cleaning up zip file..."
rm -f "$ZIP_FILE"

# Optional: Remove old backup after successful install
rm -rf tauraro_old 2>/dev/null

# Setup PATH
echo "🔧 Setting up PATH..."
touch "$HOME/.bashrc"
echo 'export PATH="$HOME/tauraro:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"

# Finalize
cd tauraro 2>/dev/null || { echo "❌ Failed to enter directory"; exit 1; }

echo ""
echo "🎉 Tauraro $LATEST_TAG installed/updated successfully!"
tauraroc --version

echo ""
echo "🧼 Cleanup completed. Ready to use!"
