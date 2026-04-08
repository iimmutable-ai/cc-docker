#!/bin/bash
# =============================================================================
# noVNC Startup Script — Visual Browser Access
# Starts Xvfb virtual display, Chromium, VNC server, and websockify bridge
#
# SECURITY: All services bind to localhost only. The docker-compose port
# mapping also uses 127.0.0.1 for host-side protection. VNC runs without
# a password (dev-only environment, localhost-bound).
#
# Usage:
#   novnc-startup          # Start all services
#   novnc-startup stop     # Stop all services
# =============================================================================

set -e

DISPLAY_NUM=99
DISPLAY=":${DISPLAY_NUM}"
SCREEN="1920x1080x24"
VNC_PORT=5900
NOVNC_PORT=6080
PID_FILE="/tmp/novnc-pids"

# -- Locate Chromium --
if command -v chromium-browser &> /dev/null; then
    CHROMIUM="chromium-browser"
elif command -v chromium &> /dev/null; then
    CHROMIUM="chromium"
elif [ -f /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome ]; then
    CHROMIUM="$(ls -d /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)"
elif [ -f /home/dev/.cache/ms-playwright/chromium-*/chrome-linux/chrome ]; then
    CHROMIUM="$(ls -d /home/dev/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)"
else
    echo "ERROR: No Chromium browser found"
    exit 1
fi

# -- Locate noVNC --
NOVNC_DIR=""
if [ -d /usr/share/novnc ]; then
    NOVNC_DIR="/usr/share/novnc"
elif [ -d /opt/noVNC ]; then
    NOVNC_DIR="/opt/noVNC"
fi

stop_services() {
    echo "Stopping noVNC services..."
    # Kill by name (more reliable than PID file for cleanup)
    killall websockify 2>/dev/null || true
    killall x11vnc 2>/dev/null || true
    killall -9 chrome chromium chromium-browser 2>/dev/null || true
    killall Xvfb 2>/dev/null || true
    # Clean up X lock files
    rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM} 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "All services stopped."
}

if [ "$1" = "stop" ]; then
    stop_services
    exit 0
fi

# -- Check if already running --
if [ -f "$PID_FILE" ] && kill -0 "$(head -1 "$PID_FILE")" 2>/dev/null; then
    echo "noVNC is already running (PID $(head -1 "$PID_FILE"))"
    echo "  VNC:  localhost:${VNC_PORT}"
    echo "  Web:  http://localhost:${NOVNC_PORT}/vnc.html"
    exit 0
fi

# -- Clean up stale state --
stop_services 2>/dev/null || true
rm -f "$PID_FILE"
sleep 0.5

# -- Start Xvfb --
echo "Starting Xvfb on display ${DISPLAY} (${SCREEN})..."
Xvfb "$DISPLAY" -screen 0 "$SCREEN" -ac +extension GLX +render -noreset &
XVFB_PID=$!
echo "$XVFB_PID" >> "$PID_FILE"

# Wait for Xvfb to be ready (poll X socket)
for i in $(seq 1 10); do
    if [ -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ]; then
        break
    fi
    sleep 0.3
done

if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    rm -f "$PID_FILE"
    exit 1
fi

# -- Start Chromium --
echo "Starting Chromium on display ${DISPLAY}..."
export DISPLAY="$DISPLAY"
"$CHROMIUM" \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --start-maximized \
    --disable-software-rasterizer \
    --disable-features=TranslateUI \
    "about:blank" \
    &>/tmp/chromium-novnc.log &
CHROMIUM_PID=$!
echo "$CHROMIUM_PID" >> "$PID_FILE"
sleep 2

if ! kill -0 "$CHROMIUM_PID" 2>/dev/null; then
    echo "WARNING: Chromium may have failed to start (see /tmp/chromium-novnc.log)"
fi

# -- Start x11vnc (localhost only) --
echo "Starting x11vnc on port ${VNC_PORT}..."
x11vnc \
    -display "$DISPLAY" \
    -rfbport "$VNC_PORT" \
    -nopw \
    -listen localhost \
    -xkb \
    -ncache 10 \
    -ncache_cr \
    -forever \
    &>/tmp/x11vnc.log &
X11VNC_PID=$!
echo "$X11VNC_PID" >> "$PID_FILE"
sleep 1

if ! kill -0 "$X11VNC_PID" 2>/dev/null; then
    echo "ERROR: x11vnc failed to start (see /tmp/x11vnc.log)"
    stop_services
    exit 1
fi

# -- Start websockify (localhost only, noVNC bridge) --
if [ -n "$NOVNC_DIR" ]; then
    echo "Starting noVNC websockify on port ${NOVNC_PORT}..."
    websockify \
        --web "$NOVNC_DIR" \
        --daemon \
        --listen 127.0.0.1:${NOVNC_PORT} \
        127.0.0.1:${VNC_PORT}
    echo ">>> noVNC ready: http://localhost:${NOVNC_PORT}/vnc.html"
else
    echo "WARNING: noVNC web directory not found. VNC available on port ${VNC_PORT} only."
    echo "  Connect with a VNC client to localhost:${VNC_PORT}"
fi

echo ""
echo "============================================="
echo "  Visual browser is running"
echo "  VNC:  localhost:${VNC_PORT}"
echo "  Web:  http://localhost:${NOVNC_PORT}/vnc.html"
echo "  Stop: novnc-startup stop"
echo "============================================="
