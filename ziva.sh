#!/bin/bash

set -e

ZIVA_REPO="$HOME/Projects/ziva/ziva-agent-plugin-godot-private"
PROJECT_PATH="$PWD"

# Load nvm and use Node 20
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20 || { echo "Node 20 is required. Run: nvm install 20"; exit 1; }

# Log directory
LOG_DIR="/tmp/ziva-logs"
mkdir -p "$LOG_DIR"

# Kill any processes using required ports
echo "Cleaning up ports 3000, 5173, and 9222..."
fuser -k 3000/tcp 2>/dev/null || true
fuser -k 5173/tcp 2>/dev/null || true
fuser -k 9222/tcp 2>/dev/null || true
sleep 0.5

# Install dependencies and build in ziva repo
cd "$ZIVA_REPO"
echo "Installing dependencies..."
pnpm install
(cd gdext && ./dev.sh)

# Symlink the dev addon to the project (so we use latest dev build)
ADDON_SRC="$ZIVA_REPO/godot-project/addons/ziva_agent"
ADDON_DST="$PROJECT_PATH/addons/ziva_agent"
echo "Linking ziva_agent addon from dev build..."
rm -rf "$ADDON_DST" 2>/dev/null || true
mkdir -p "$PROJECT_PATH/addons"
ln -sf "$ADDON_SRC" "$ADDON_DST"
rm -rf "$PROJECT_PATH/.godot/extension_list.cfg" 2>/dev/null || true

# Start servers
echo "Starting web server on port 3000..."
pnpm --filter @repo/web dev > "$LOG_DIR/web.log" 2>&1 &

echo "Starting plugin-app on port 5173..."
pnpm --filter @repo/plugin-app dev > "$LOG_DIR/plugin-app.log" 2>&1 &

echo "Waiting for servers to start..."
sleep 5

echo ""
echo "=== Logs available at ==="
echo "  Web server:  $LOG_DIR/web.log"
echo "  Plugin app:  $LOG_DIR/plugin-app.log"
echo "  Godot:       $LOG_DIR/godot.log"
echo "========================="
echo ""

# Open Godot with CookiePenguin
godot -e --path "$PROJECT_PATH" 2>&1 | tee "$LOG_DIR/godot.log"
