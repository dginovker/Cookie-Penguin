# Build the server
godot --headless --export-debug "Linux"

# Build the webclient
rm build.zip
rm build/index.html ; godot --headless --export-debug "Web" ./build/index.html ; 

# Package the build for itch.io
zip -r build.zip build 
