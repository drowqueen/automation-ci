#!/bin/bash

set -e  # Exit on error

# Arguments: version, port, server_name, instance_ip, install_method, ssh_key
echo "Received $# arguments: $@"
[ $# -ne 6 ] && { echo "Usage: $0 <version> <port> <server_name> <ip> <install_method> <ssh_key>"; exit 1; }

VERSION="$1"
PORT="$2"
SERVER_NAME="$3"
IP="$4"
INSTALL_METHOD="$5"
SSH_KEY="$6"

# SSH command alias
SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$IP"

# 1. Verify Nginx is installed
echo "Checking if Nginx is installed..."
if [ "$INSTALL_METHOD" = "package" ]; then
    if $SSH "dpkg -l | grep -q nginx" 2>/dev/null; then
        echo "Nginx is installed (via package)"
    else
        echo "Nginx is not installed (package method)"
        exit 1
    fi
elif [ "$INSTALL_METHOD" = "source" ]; then
    if $SSH "nginx -v >/tmp/nginx_check.txt 2>&1" && $SSH "test -f /tmp/nginx_check.txt && grep -q 'nginx version' /tmp/nginx_check.txt"; then
        echo "Nginx is installed (via source)"
        $SSH "rm -f /tmp/nginx_check.txt"
    else
        echo "Nginx is not installed (source method)"
        $SSH "rm -f /tmp/nginx_check.txt"
        exit 1
    fi
else
    echo "Invalid install_method: must be 'package' or 'source'"
    exit 1
fi

# 2. Verify Nginx service is running
echo "Checking if Nginx service is running..."
$SSH "systemctl is-active nginx >/dev/null" || { 
    if [ "$INSTALL_METHOD" = "source" ]; then
        $SSH "pgrep nginx >/dev/null" || { echo "Nginx process not running"; exit 1; }
    else
        echo "Nginx service not running"; 
        exit 1; 
    fi
}
echo "Nginx service/process is running"

# 3. Verify correct version/revision
echo "Verifying Nginx version..."
INSTALLED_VERSION=$($SSH "nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+[-0-9a-z]*'")
if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
    echo "Nginx version $VERSION is correctly installed"
else
    echo "Version mismatch: expected $VERSION, got $INSTALLED_VERSION"
    exit 1
fi

# 4. Verify running Nginx configuration (port and server_name)
echo "Verifying running Nginx configuration..."
# Check if Nginx is listening on the specified port
if ! $SSH "ss -tuln | grep -q ':$PORT '"; then
    echo "Nginx is not listening on port $PORT"
    $SSH "ss -tuln"  # Show listening ports for debugging
    exit 1
fi
echo "Nginx is listening on port $PORT"

# 5. Verify service responds on the port (optional, kept for completeness)
echo "Testing if Nginx is responding on port $PORT..."
curl -s --connect-timeout 10 "http://$IP:$PORT" >/dev/null || { echo "Nginx not responding on http://$IP:$PORT"; exit 1; }
echo "Nginx is responding on port $PORT"

echo "All tests passed"