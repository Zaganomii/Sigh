#!/bin/bash

# Exit on error
set -e

# Directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_DIR="$(pwd)"

FRONTEND_PID=""
BACKEND_PID=""

echo "============================================================"
echo "SIGH - Student Information Helper Generator"
echo "============================================================"
echo ""
echo "Resources:"
echo "  Backend:  http://localhost:8000"
echo "  Frontend: http://localhost:8081"
echo ""
echo "Status: Skeleton/Starting Point"
echo ""
echo "Features implemented:"
echo "  - Session management API"
echo "  - Person management API"
echo "  - Attendance tracking API"
echo "  - Dashboard stats API"
echo "  - Flutter frontend with basic screens"
echo ""
echo "Remaining work:"
echo "  - Face recognition integration for attendance"
echo "  - Real-time participant tracking via WebSocket"
echo "  - Mobile app finalization"
echo "============================================================"

# --- Sanity check: is Windows Python reachable from WSL? ---
if ! command -v python.exe >/dev/null 2>&1; then
    echo "ERROR: 'python.exe' not found on PATH."
    echo "Make sure Windows Python is installed and WSL interop is enabled."
    echo "Try:  python.exe --version"
    exit 1
fi

echo "Using Windows Python: $(python.exe --version 2>&1)"

# ============================================================
# Helpers
# ============================================================

# Recursively kill a process and all of its children.
kill_tree() {
    local pid="$1"
    [ -z "$pid" ] && return 0
    local child
    for child in $(pgrep -P "$pid" 2>/dev/null || true); do
        kill_tree "$child"
    done
    kill "$pid" 2>/dev/null || true
}

# WSL interop sometimes leaves the Windows-side process orphaned.
# Kill only the specific python.exe started for daphne, matched by
# its command line (safer than killing all python.exe).
kill_windows_daphne() {
    cmd.exe /C "wmic process where \"commandline like '%daphne%sigh_backend_yunet%'\" call terminate" \
        >/dev/null 2>&1 || true
}

# Wait until nothing is listening on the given port (best effort).
wait_port_free() {
    local port="$1"
    local tries=20
    command -v ss >/dev/null 2>&1 || { sleep 1; return 0; }
    while [ "$tries" -gt 0 ]; do
        if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$"; then
            return 0
        fi
        sleep 0.5
        tries=$((tries - 1))
    done
    return 0
}

# ============================================================
# Start / stop / reload: Frontend
# ============================================================

start_frontend() {
    echo "Starting Flutter frontend on port 8081..."
    cd "$SCRIPT_DIR/frontend"
    # stdin from /dev/null so flutter doesn't eat our control keys
    flutter run -d web-server --web-port 8081 < /dev/null &
    FRONTEND_PID=$!
    cd "$ORIGINAL_DIR"
    echo "Frontend started (pid $FRONTEND_PID)."
}

stop_frontend() {
    if [ -n "$FRONTEND_PID" ]; then
        echo "Stopping frontend (pid $FRONTEND_PID)..."
        kill_tree "$FRONTEND_PID"
        FRONTEND_PID=""
        wait_port_free 8081
    fi
}

reload_frontend() {
    echo ""
    echo ">>> Reloading FRONTEND..."
    stop_frontend
    start_frontend
    print_controls
}

# ============================================================
# Start / stop / reload: Backend
# ============================================================

start_backend() {
    echo "Starting Daphne backend on port 8000..."
    cd "$SCRIPT_DIR/backend"
    python.exe -m daphne -b 0.0.0.0 -p 8000 sigh_backend_yunet.asgi:application < /dev/null &
    BACKEND_PID=$!
    cd "$ORIGINAL_DIR"
    echo "Backend started (pid $BACKEND_PID)."
}

stop_backend() {
    if [ -n "$BACKEND_PID" ]; then
        echo "Stopping backend (pid $BACKEND_PID)..."
        kill_tree "$BACKEND_PID"
        BACKEND_PID=""
    fi
    kill_windows_daphne
    wait_port_free 8000
}

reload_backend() {
    echo ""
    echo ">>> Reloading BACKEND..."
    stop_backend
    start_backend
    print_controls
}

# ============================================================
# Clean shutdown
# ============================================================

cleanup() {
    echo ""
    echo "Shutting down..."

    stop_frontend
    stop_backend

    cd "$ORIGINAL_DIR"
    exit 0
}

trap cleanup SIGINT SIGTERM

print_controls() {
    echo ""
    echo "------------------------------------------------------------"
    echo " Controls:  [a] reload backend   [z] reload frontend"
    echo "            [r] reload both      [q] quit"
    echo "------------------------------------------------------------"
    echo ""
}

# ============================================================
# Go
# ============================================================

start_frontend
start_backend

print_controls

# Key loop — keeps the script alive while the servers run.
while true; do
    if ! read -rsn1 key; then
        # stdin closed (e.g. piped) — just wait for the children
        wait
        break
    fi

    case "$key" in
        a|A) reload_backend ;;
        z|Z) reload_frontend ;;
        r|R) reload_backend; reload_frontend ;;
        q|Q) cleanup ;;
        *)   ;;
    esac
done
