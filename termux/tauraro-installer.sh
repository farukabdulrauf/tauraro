#!/bin/bash

echo "===================================="
echo "🚀 Tauraro Installation Script"
echo "===================================="

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts=${1:-5}
    local command="$2"
    local description="$3"
    local attempt=1
    local delay=1

    while [ $attempt -le $max_attempts ]; do
        echo "🔄 Attempt $attempt/$max_attempts: $description"
        eval "$command"
        
        if [ $? -eq 0 ]; then
            echo "✅ Success on attempt $attempt"
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo "❌ Attempt $attempt failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff: 1, 2, 4, 8, 16...
        fi
        attempt=$((attempt + 1))
    done

    echo "❌ Failed after $max_attempts attempts: $description"
    return 1
}

# Check internet connection
check_internet() {
    echo "🌐 Checking internet connection..."
    if ! ping -c 1 8.8.8.8 &> /dev/null && ! ping -c 1 google.com &> /dev/null; then
        echo "❌ No internet connection detected!"
        echo "Please connect to the internet and try again."
        exit 1
    fi
    echo "✅ Internet is available"
}

# Main installation
check_internet

# Update & Upgrade with retry
retry_with_backoff 4 \
    "pkg update -y && pkg upgrade -y" \
    "Updating Termux packages"

# Download with retry + curl built-in retries
retry_with_backoff 5 \
    "curl -L -O -f --retry 3 --retry-delay 5 --retry-max-time 60 https://github.com/tauraro/tauraro/releases/download/v0.0.3/tauraroc-linux-arm64.zip" \
    "Downloading Tauraro"

# Verify download
if [ ! -f "tauraroc-linux-arm64.zip" ]; then
    echo "❌ Downloaded file not found!"
    exit 1
fi

# Extract
retry_with_backoff 3 \
    "unzip -o tauraroc-linux-arm64.zip -d tauraro" \
    "Extracting files"

# Add to PATH (only once)
if ! grep -q "tauraro" \~/.bashrc; then
    echo 'export PATH="$HOME/tauraro:$PATH"' >> \~/.bashrc
    echo "✅ Added Tauraro to PATH permanently"
else
    echo "ℹ️  Tauraro is already in PATH"
fi

# Reload shell
source \~/.bashrc

# Verify installation
cd tauraro 2>/dev/null || { echo "❌ Could not enter tauraro directory"; exit 1; }

echo "🔍 Checking installed version..."
tauraroc --version

echo ""
echo "🎉 Installation completed successfully!"
echo "You can now use 'tauraroc' command from anywhere."
echo "===================================="
