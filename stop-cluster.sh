#!/bin/bash
# Stop and Cleanup Hadoop Cluster

echo "==================================================="
echo "Stopping Hadoop Cluster"
echo "==================================================="

# Stop and remove all containers
echo "Stopping containers..."
docker rm -f namenode datanode1 datanode2 2>/dev/null || true

echo "All containers removed."

# Remove network
echo ""
echo "Removing Docker network..."
docker network rm hadoop-network 2>/dev/null || true

echo ""
echo "Do you want to remove the data volumes as well? (y/n)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    echo "Removing data volumes..."
    docker volume rm hadoop-namenode-data hadoop-datanode1-data hadoop-datanode2-data 2>/dev/null || true
    echo "Data volumes removed."
fi

echo ""
echo "==================================================="
echo "Hadoop Cluster Stopped and Cleaned Up!"
echo "==================================================="
