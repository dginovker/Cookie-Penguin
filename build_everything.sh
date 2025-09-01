#!/bin/bash
set -e  # Exit immediately if any command fails

echo "Cleaning old build..."

# Clean it up
rm -f build.zip
rm -rf build/
mkdir build

echo "Building Linux server.."

# Build the server
godot --headless --export-debug "Linux" 

# Only build the web client if --no-webclient wasn't passed
if [[ ! " $@ " =~ " --no-webclient " ]]; then
    echo "Building Web client..."
    godot --headless --export-debug "Web" ./build/index.html
else
    echo "Skipping Web client build..."
fi
echo "Building Web client..."

# Package the build for itch.io
zip -r build.zip build 
