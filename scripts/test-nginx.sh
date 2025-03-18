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
    $SSH "dpkg -l | grep -q nginx" || { echo "Nginx package not installed"; exit 1; }
    echo "Nginx package is installed"
elif [ "$INSTALL_METHOD" = "source" ]; then
    $SSH "nginx -v >/tmp/nginx_check.txt 2>&1" 
    $SSH "test -f /tmp/nginx_check.txt && grep -q 'nginx version' /tmp/nginx_check.txt" || { 
        echo "Nginx not found or not installed from source"; 
        $SSH "rm -f /tmp/nginx_check.txt"; 
        exit 1; 
    }
    $SSH "rm -f /tmp/nginx_check.txt"
    echo "Nginx source installation detected"
else
    echo "Invalid install_method: must be 'package' or 'source'"
    exit 1

# 2. Verify Nginx service is running
echo "Checking if Nginx service is running..."
$SSH "systemctl is-active nginx >/dev/null" || { echo "Nginx service not running"; exit 1; }
echo "Nginx service is running"

# 3. Verify correct version/revision
echo "Verifying Nginx version..."
INSTALLED_VERSION=$($SSH "nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+[-0-9a-z]*'")
if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
    echo "Nginx version $VERSION is correctly installed"
else
    echo "Version mismatch: expected $VERSION, got $INSTALLED_VERSION"
    exit 1
fi

# 4. Verify configuration changes (port and server_name)
echo "Verifying Nginx configuration..."
$SSH "grep -q 'listen $PORT' /etc/nginx/sites-enabled/default && grep -q 'server_name $SERVER_NAME' /etc/nginx/sites-enabled/default" || {
    echo "Configuration mismatch: listen $PORT or server_name $SERVER_NAME not found in /etc/nginx/sites-enabled/default"
    exit 1
}
echo "Configuration (listen $PORT, server_name $SERVER_NAME) is correctly applied"

# 5. Verify service listens on the port
echo "Testing if Nginx is listening on port $PORT..."
curl -s --connect-timeout 10 "http://$IP:$PORT" >/dev/null || { echo "Nginx not responding on http://$IP:$PORT"; exit 1; }
echo "Nginx is listening on port $PORT"

echo "All tests passed"