#!/bin/bash
# Start container with SSH and Hadoop services

# Get hostname
HOSTNAME=$(hostname)

echo "Starting container: $HOSTNAME"

# Generate SSH host keys if not present
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A 2>/dev/null || true
fi

# Start SSH service
echo "Starting SSH service..."
/usr/sbin/sshd

# Wait for SSH to be ready
sleep 2

# Verify SSH is running
if pgrep -x sshd > /dev/null; then
    echo "SSH service is running on port 22"
else
    echo "Warning: SSH service may not be running"
fi

# Add all hosts to known_hosts
ssh-keyscan -H namenode datanode1 datanode2 resourcemanager nodemanager1 nodemanager2 >> /root/.ssh/known_hosts 2>/dev/null || true

# Create data directory
mkdir -p /opt/hadoop/datanode-data 2>/dev/null || true

# Source environment
source /opt/hadoop/etc/hadoop/hadoop-env.sh

echo "Container $HOSTNAME is ready"

# Start appropriate services based on hostname
if [ "$HOSTNAME" = "namenode" ]; then
    echo "Starting NameNode and ResourceManager..."
    /opt/hadoop/sbin/start-dfs.sh
    /opt/hadoop/sbin/start-yarn.sh
elif [ "$HOSTNAME" = "datanode1" ] || [ "$HOSTNAME" = "datanode2" ]; then
    echo "Starting DataNode and NodeManager..."
    /opt/hadoop/sbin/start-dfs.sh
    /opt/hadoop/sbin/start-yarn.sh
fi

# Keep container running
echo "Services started, keeping container running..."
tail -f /dev/null
