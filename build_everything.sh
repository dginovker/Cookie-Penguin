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

echo "Building Web client..."

# Build the webclient
godot --headless --export-debug "Web" ./build/index.html

# Package the build for itch.io
zip -r build.zip build 
