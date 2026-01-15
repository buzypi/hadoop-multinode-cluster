#!/bin/bash
# Start Hadoop Cluster with proper SSH and service initialization

echo "==================================="
echo "Starting Hadoop Multi-Node Cluster"
echo "==================================="

# Source hadoop environment
source /opt/hadoop/etc/hadoop/hadoop-env.sh

echo "Sourced Hadoop environment variables"
echo ""

# Update /etc/hosts with all node hostnames
cat > /etc/hosts << 'HOSTSEOF'
127.0.0.1       localhost
172.20.0.10     namenode
172.20.0.11     datanode1
172.20.0.12     datanode2
HOSTSEOF

echo "Configured /etc/hosts:"
cat /etc/hosts
echo ""

# Generate SSH host keys if not present
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A 2>/dev/null || true
fi

# Start SSH service
echo "Starting SSH service..."
/usr/sbin/sshd

# Wait for SSH to be ready
echo "Waiting for SSH service to start..."
sleep 2

# Verify SSH is running
if pgrep -x sshd > /dev/null; then
    echo "SSH service is running"
else
    echo "Warning: SSH service may not be running properly"
fi

echo ""

# Configure passwordless SSH to all nodes (including itself)
echo "Configuring SSH for passwordless access..."
ssh-keyscan -H namenode datanode1 datanode2 >> /root/.ssh/known_hosts 2>/dev/null || true

# Create necessary directories
echo "Creating Hadoop data directories..."
mkdir -p /opt/hadoop/namenode-data
mkdir -p /opt/hadoop/datanode-data

# Remove previous PID files if they exist
rm -f /tmp/hadoop-*-pid.pid 2>/dev/null || true

echo ""
echo "==================================="
echo "Starting HDFS Services"
echo "==================================="

# Start HDFS services (NameNode)
/opt/hadoop/sbin/start-dfs.sh

echo ""
echo "==================================="
echo "Starting YARN Services"
echo "==================================="

# Start YARN services (ResourceManager)
/opt/hadoop/sbin/start-yarn.sh

echo ""
echo "==================================="
echo "Initialization Complete"
echo "==================================="

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 15

# Check if NameNode is running
echo ""
echo "Checking NameNode status..."
/opt/hadoop/bin/hdfs dfsadmin -report || echo "NameNode report not available yet"

echo ""
echo "==================================="
echo "Hadoop Cluster Started Successfully!"
echo "==================================="
echo ""
echo "Web Interfaces:"
echo "  - HDFS NameNode:       http://localhost:9870"
echo "  - YARN ResourceManager: http://localhost:8088"
echo "  - MapReduce JobHistory: http://localhost:19888"
echo ""
echo "Useful Commands:"
echo "  - Check cluster: hdfs dfsadmin -report"
echo "  - List files: hdfs dfs -ls /"
echo "  - View containers: docker ps"
echo "==================================="

# Keep container running and tail logs
tail -f /dev/null
