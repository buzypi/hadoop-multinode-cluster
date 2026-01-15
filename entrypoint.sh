#!/bin/bash
# Hadoop Container Entrypoint Script
# This script initializes SSH and starts appropriate Hadoop services

set -e

echo "========================================"
echo "Hadoop Container Entrypoint"
echo "========================================"
echo "Hostname: $(hostname)"
echo ""

# Source Hadoop environment
source /opt/hadoop/etc/hadoop/hadoop-env.sh

# Generate SSH host keys if not present
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Update /etc/hosts with all node hostnames
cat > /etc/hosts << 'HOSTSEOF'
127.0.0.1       localhost
172.18.0.2      namenode
172.18.0.3      datanode1
172.18.0.4      datanode2
HOSTSEOF

echo "Hosts file configured:"
cat /etc/hosts
echo ""

# Start SSH service
echo "Starting SSH service..."
/usr/sbin/sshd

# Wait for SSH to be ready
sleep 2

# Configure SSH known hosts with IP addresses
echo "Configuring SSH known_hosts..."
ssh-keyscan -H 172.18.0.2 172.18.0.3 172.18.0.4 >> /root/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -H namenode datanode1 datanode2 >> /root/.ssh/known_hosts 2>/dev/null || true

# Verify SSH is running
if pgrep -x sshd > /dev/null; then
    echo "SSH service is running on port 22"
else
    echo "WARNING: SSH service may not be running properly"
fi


echo ""
echo "========================================"
echo "Starting Hadoop Services"
echo "========================================"

# Create data directory
mkdir -p /opt/hadoop/namenode-data 2>/dev/null || true
mkdir -p /opt/hadoop/datanode-data 2>/dev/null || true

# Function to wait for datanodes to be reachable via SSH
wait_for_datanodes() {
    local max_wait=60
    local elapsed=0
    echo "Waiting for datanodes to be SSH reachable..."
    
    while [ $elapsed -lt $max_wait ]; do
        if ssh -o ConnectTimeout=2 datanode1 "exit 0" 2>/dev/null && \
           ssh -o ConnectTimeout=2 datanode2 "exit 0" 2>/dev/null; then
            echo "All datanodes are SSH reachable"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    echo "Warning: Timeout waiting for datanodes (continuing anyway)..."
    return 1
}

# Start appropriate services based on hostname
case "$(hostname)" in
    namenode)
        echo "Starting NameNode..."
        
        # Wait for datanodes to be SSH reachable
        wait_for_datanodes
        
        # Give SSH a moment to settle
        sleep 2
        
        # Format namenode if not already formatted
        if [ ! -d "/opt/hadoop/namenode-data/current" ]; then
            echo "Formatting NameNode..."
            /opt/hadoop/bin/hdfs namenode -format -force -nonInteractive || {
                echo "NameNode formatting failed"
                exit 1
            }
            echo "NameNode formatted successfully"
        else
            echo "NameNode already formatted, skipping format"
        fi
        
        echo "Starting HDFS services (this will start namenode and datanodes)..."
        /opt/hadoop/sbin/start-dfs.sh
        
        echo "Starting YARN services..."
        /opt/hadoop/sbin/start-yarn.sh
        ;;
    datanode1|datanode2)
        echo "DataNode ($(hostname)) ready, waiting for namenode to start services..."
        # Don't start services here - let the namenode orchestrate via SSH
        # Just keep the container running
        tail -f /dev/null
        ;;
    *)
        echo "Unknown hostname, starting all services..."
        /opt/hadoop/sbin/start-dfs.sh
        /opt/hadoop/sbin/start-yarn.sh
        ;;
esac

echo ""
echo "========================================"
echo "Services Started Successfully!"
echo "========================================"
echo "Container: $(hostname)"
echo ""

# Keep container running
tail -f /dev/null
