#!/bin/bash
set -e  # Exit immediately if any command fails

# Build the server
godot --headless --export-debug "Linux" 

# Build the webclient
rm -f build.zip
rm -f build/index.html 

godot --headless --export-debug "Web" ./build/index.html

# Package the build for itch.io
zip -r build.zip build 
