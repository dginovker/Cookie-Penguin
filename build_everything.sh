#!/bin/bash
set -e  # Exit immediately if any command fails

echo "Generating version info..."
# Get git version info
VERSION_HASH=$(git rev-parse --short HEAD)
VERSION_COUNT=$(git rev-list --count HEAD)

# Generate version.gd file
cat > version.gd << EOF
extends Resource
class_name GameVersion

const HASH = "$VERSION_HASH"
const COUNT = $VERSION_COUNT
EOF

echo "Game version: $VERSION_HASH (#$VERSION_COUNT)"

echo "Cleaning old build..."

# Clean it up
rm -f build.zip
rm -rf build/
mkdir build

# Only build the server if --no-server wasn't passed
if [[ ! " $@ " =~ " --no-server " ]]; then
    echo "Building Linux server.."
    godot --headless --export-debug "Linux" 
else
    echo "Skipping Server build..."
fi

# Only build the web client if --no-webclient wasn't passed
if [[ ! " $@ " =~ " --no-webclient " ]]; then
    echo "Building Web client..."
    godot --headless --export-debug "Web" ./build/index.html
else
    echo "Skipping Web client build..."
fi

# Package the build for itch.io
zip -r build.zip build 
