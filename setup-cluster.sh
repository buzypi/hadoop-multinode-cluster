#!/bin/bash
# Hadoop Multi-Node Cluster Setup Script
# This script sets up a complete Hadoop cluster with:
# - 1 NameNode (with ResourceManager)
# - 2 DataNodes (each with NodeManager)

set -e

echo "==================================================="
echo "Hadoop Multi-Node Cluster Setup"
echo "==================================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Build the Docker image
echo "Step 1: Building Hadoop Docker image..."
docker build -t hadoop-base:latest .
echo "Image built successfully!"
echo ""

# Stop and remove existing containers if they exist
echo "Step 2: Cleaning up existing containers..."
docker rm -f namenode datanode1 datanode2 2>/dev/null || true
echo ""

# Create Docker network for the cluster
echo "Step 3: Creating Docker network..."
docker network rm hadoop-network 2>/dev/null || true
docker network create --driver bridge hadoop-network
echo "Network 'hadoop-network' created."
echo ""

# Create data volumes for HDFS
echo "Step 4: Creating data volumes..."
docker volume create hadoop-namenode-data 2>/dev/null || true
docker volume create hadoop-datanode1-data 2>/dev/null || true
docker volume create hadoop-datanode2-data 2>/dev/null || true
echo "Data volumes created."
echo ""

# Common environment variables
ENV_VARS="-e HDFS_NAMENODE_USER=root -e HDFS_DATANODE_USER=root -e HDFS_SECONDARYNAMENODE_USER=root -e YARN_RESOURCEMANAGER_USER=root -e YARN_NODEMANAGER_USER=root"

# Start NameNode (with ResourceManager)
echo "Step 5: Starting NameNode..."
docker run -d \
    --name namenode \
    --network hadoop-network \
    --hostname namenode \
    -p 9870:9870 \
    -p 9000:9000 \
    -p 19888:19888 \
    -p 8088:8088 \
    $ENV_VARS \
    -v hadoop-namenode-data:/opt/hadoop/namenode-data \
    hadoop-base:latest

echo "NameNode started (ID: $(docker ps -q --filter name=namenode))"
echo ""

# Wait for NameNode to be ready
echo "Waiting for NameNode to be ready..."
sleep 20

# Start DataNode 1 (with NodeManager 1)
echo "Step 6: Starting DataNode1..."
docker run -d \
    --name datanode1 \
    --network hadoop-network \
    --hostname datanode1 \
    -p 9864:9864 \
    -p 8042:8042 \
    $ENV_VARS \
    -v hadoop-datanode1-data:/opt/hadoop/datanode-data \
    hadoop-base:latest

echo "DataNode1 started (ID: $(docker ps -q --filter name=datanode1))"
echo ""

# Wait for DataNode1 to be ready
sleep 10

# Start DataNode 2 (with NodeManager 2)
echo "Step 7: Starting DataNode2..."
docker run -d \
    --name datanode2 \
    --network hadoop-network \
    --hostname datanode2 \
    -p 9865:9865 \
    -p 8043:8043 \
    $ENV_VARS \
    -v hadoop-datanode2-data:/opt/hadoop/datanode-data \
    hadoop-base:latest

echo "DataNode2 started (ID: $(docker ps -q --filter name=datanode2))"
echo ""

# Wait for all services to initialize
echo "Waiting for cluster services to initialize..."
sleep 30

echo ""
echo "==================================================="
echo "Hadoop Cluster Setup Complete!"
echo "==================================================="
echo ""
echo "Web Interfaces (accessible from host machine):"
echo "  - HDFS NameNode UI:       http://localhost:9870"
echo "  - YARN ResourceManager:   http://localhost:8088"
echo "  - MapReduce JobHistory:   http://localhost:19888"
echo ""
echo "Container Status:"
docker ps --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode" || true
echo ""
echo "Useful Commands:"
echo "  - Check cluster status:  docker exec namenode hdfs dfsadmin -report"
echo "  - View HDFS files:       docker exec namenode hdfs dfs -ls /"
echo "  - Run WordCount:        ./run-wordcount.sh"
echo "  - Stop cluster:         ./stop-cluster.sh"
echo "  - View logs:           docker logs -f namenode"
echo "==================================================="
