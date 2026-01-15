#!/bin/bash
# Gracefully decommission a DataNode from the running Hadoop cluster.

set -euo pipefail

NODE_NAME="${1:-}"
WAIT_FLAG="${2:-}"

if [ -z "${NODE_NAME}" ]; then
    echo "Usage: $0 <datanode-name> [--wait]"
    echo "Example: $0 datanode3 --wait"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx 'namenode'; then
    echo "Error: 'namenode' container is not running."
    exit 1
fi

EXCLUDE_FILE="/opt/hadoop/etc/hadoop/dfs.exclude"
HDFS_SITE="/opt/hadoop/etc/hadoop/hdfs-site.xml"

echo "==================================================="
echo "Decommissioning ${NODE_NAME}"
echo "==================================================="
echo ""

echo "Step 1: Ensure dfs.hosts.exclude is configured..."
docker exec namenode bash -c "grep -q '<name>dfs.hosts.exclude</name>' ${HDFS_SITE} || \
  sed -i '/<\/configuration>/i\    <property>\n        <name>dfs.hosts.exclude</name>\n        <value>${EXCLUDE_FILE}</value>\n    </property>\n' ${HDFS_SITE}"
echo "dfs.hosts.exclude configured."
echo ""

echo "Step 2: Add ${NODE_NAME} to ${EXCLUDE_FILE}..."
docker exec namenode bash -c "mkdir -p /opt/hadoop/etc/hadoop && touch ${EXCLUDE_FILE} && \
  awk -v node='${NODE_NAME}' '\$0==node{found=1} {print} END{if(!found){print node}}' ${EXCLUDE_FILE} > /tmp/dfs.exclude && \
  mv /tmp/dfs.exclude ${EXCLUDE_FILE}"
echo "Exclude file updated."
echo ""

echo "Step 3: Refresh NameNode nodes..."
docker exec namenode /opt/hadoop/bin/hdfs dfsadmin -refreshNodes
echo "Refresh requested."
echo ""

echo "Step 4: Check decommission status..."
status=$(docker exec namenode /opt/hadoop/bin/hdfs dfsadmin -report | \
  awk -v node="${NODE_NAME}" '
    $0 ~ "Hostname: "node"$" {matchnode=1}
    matchnode && $0 ~ "Decommission Status" {print $NF; exit}
  ')
status=${status:-Unknown}
echo "Decommission Status: ${status}"
echo ""

if [ "${WAIT_FLAG}" = "--wait" ]; then
    echo "Waiting for decommission to complete..."
    max_wait=300
    elapsed=0
    while [ "${elapsed}" -lt "${max_wait}" ]; do
        status=$(docker exec namenode /opt/hadoop/bin/hdfs dfsadmin -report | \
          awk -v node="${NODE_NAME}" '
            $0 ~ "Hostname: "node"$" {matchnode=1}
            matchnode && $0 ~ "Decommission Status" {print $NF; exit}
          ')
        status=${status:-Unknown}
        if [ "${status}" = "Decommissioned" ]; then
            echo "Decommission Status: ${status}"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    if [ "${elapsed}" -ge "${max_wait}" ]; then
        echo "Timed out waiting for decommission. Check status manually:"
        echo "  docker exec namenode hdfs dfsadmin -report"
    fi
fi

echo ""
echo "==================================================="
echo "Decommission Requested"
echo "==================================================="
echo "Next steps (after decommission completes):"
echo "  - Stop the container: docker rm -f ${NODE_NAME}"
echo "  - Remove volume (optional): docker volume rm hadoop-${NODE_NAME}-data"
echo "  - Remove from workers (optional):"
echo "      docker exec namenode bash -c \"grep -vx '${NODE_NAME}' /opt/hadoop/etc/hadoop/workers > /tmp/workers && mv /tmp/workers /opt/hadoop/etc/hadoop/workers\""
echo "==================================================="
