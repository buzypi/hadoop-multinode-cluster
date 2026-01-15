#!/bin/bash
# Add a new Hadoop DataNode (with NodeManager) to the running cluster.

set -euo pipefail

NODE_NUM="${1:-3}"
NODE_NAME="datanode${NODE_NUM}"

if ! [[ "$NODE_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: node number must be an integer (e.g., 3)."
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

if ! docker network inspect hadoop-network > /dev/null 2>&1; then
    echo "Error: Docker network 'hadoop-network' not found. Run setup-cluster.sh first."
    exit 1
fi

if ! docker image inspect hadoop-base:latest > /dev/null 2>&1; then
    echo "Error: Docker image 'hadoop-base:latest' not found. Run setup-cluster.sh first."
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx "${NODE_NAME}"; then
    echo "Error: Container '${NODE_NAME}' already exists. Remove it first if needed."
    exit 1
fi

# Host ports follow the existing pattern:
# datanode1 -> 9864/8042, datanode2 -> 9865/8043, etc.
HOST_DN_PORT=$((9863 + NODE_NUM))
HOST_NM_PORT=$((8041 + NODE_NUM))

VOLUME="hadoop-${NODE_NAME}-data"
ENV_VARS="-e HDFS_NAMENODE_USER=root -e HDFS_DATANODE_USER=root -e HDFS_SECONDARYNAMENODE_USER=root -e YARN_RESOURCEMANAGER_USER=root -e YARN_NODEMANAGER_USER=root"

echo "==================================================="
echo "Adding ${NODE_NAME} to Hadoop Cluster"
echo "==================================================="
echo ""

echo "Step 1: Creating data volume..."
docker volume create "${VOLUME}" > /dev/null
echo "Volume '${VOLUME}' created."
echo ""

echo "Step 2: Starting ${NODE_NAME} container..."
docker run -d \
    --name "${NODE_NAME}" \
    --network hadoop-network \
    --hostname "${NODE_NAME}" \
    -p "${HOST_DN_PORT}:9864" \
    -p "${HOST_NM_PORT}:8042" \
    ${ENV_VARS} \
    -v "${VOLUME}:/opt/hadoop/datanode-data" \
    --entrypoint /bin/bash \
    hadoop-base:latest \
    -c 'set -e; mkdir -p /opt/hadoop/datanode-data; if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then ssh-keygen -A; fi; /usr/sbin/sshd; tail -f /dev/null'

echo "${NODE_NAME} started (ID: $(docker ps -q --filter name="${NODE_NAME}"))"
echo ""

echo "Step 3: Registering ${NODE_NAME} with NameNode..."
docker exec namenode bash -c "awk -v node='${NODE_NAME}' '\$0==node{found=1} {print} END{if(!found){print node}}' /opt/hadoop/etc/hadoop/workers > /tmp/workers && mv /tmp/workers /opt/hadoop/etc/hadoop/workers"
docker exec "${NODE_NAME}" /opt/hadoop/bin/hdfs --daemon start datanode
docker exec "${NODE_NAME}" /opt/hadoop/bin/yarn --daemon start nodemanager
echo ""

echo "==================================================="
echo "DataNode Added Successfully!"
echo "==================================================="
echo "Container Status:"
docker ps --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode" || true
echo ""
echo "Useful Commands:"
echo "  - Check cluster status:  docker exec namenode hdfs dfsadmin -report"
echo "  - View logs:             docker logs -f ${NODE_NAME}"
echo "==================================================="
