#!/bin/bash

set -e  # Exit on error

# Arguments: version, port, server_name, instance_ip, ssh_key_path, install_method
echo "Received $# arguments: $@"
[ $# -ne 6 ] && { echo "Usage: $0 <version> <port> <server_name> <ip> <ssh_key> <install_method>"; exit 1; }

VERSION="$1"
PORT="$2"
SERVER_NAME="$3"
IP="$4"
KEY="$5"
INSTALL_METHOD="$6"

# SSH command alias for brevity
SSH="ssh -o StrictHostKeyChecking=no -i $KEY ubuntu@$IP"

# Check if Nginx is installed based on install method
if [ "$INSTALL_METHOD" = "package" ]; then
    $SSH "dpkg -l | grep -q nginx" || { echo "Nginx package not installed"; exit 1; }
    echo "Nginx package is installed"
elif [ "$INSTALL_METHOD" = "source" ]; then
    $SSH "test -f /usr/local/nginx/sbin/nginx" || { echo "Nginx binary not installed at /usr/local/nginx/sbin/nginx"; exit 1; }
    echo "Nginx source binary is installed"
else
    echo "Unknown install_method: $INSTALL_METHOD"; exit 1
fi

# Check if Nginx service is running
$SSH "systemctl is-active nginx >/dev/null" || { echo "Nginx service not running"; exit 1; }
echo "Nginx service is running"

# Check version
$SSH "nginx -v 2>&1 | grep -q $VERSION" || { echo "Expected version $VERSION not found"; exit 1; }
echo "Version $VERSION confirmed"

# Check configuration
$SSH "grep 'listen $PORT' /etc/nginx/nginx.conf >/dev/null && grep 'server_name $SERVER_NAME' /etc/nginx/nginx.conf >/dev/null" || { echo "Config (port $PORT, server $SERVER_NAME) not applied"; exit 1; }
echo "Config applied"

# Check port listening
sleep 10  # Wait for instance
curl -s --connect-timeout 10 "http://$IP:$PORT" >/dev/null || { echo "Not listening on port $PORT"; exit 1; }
echo "Listening on port $PORT"

echo "All tests passed"