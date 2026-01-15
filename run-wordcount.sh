#!/bin/bash
# Run WordCount Program on Hadoop Cluster

echo "==================================="
echo "Running WordCount Program"
echo "==================================="

# Check if namenode container is running
if ! docker ps --format '{{.Names}}' | grep -q namenode; then
    echo "Error: namenode container is not running!"
    echo "Please start the cluster first: ./setup-cluster.sh"
    exit 1
fi

# Create sample input
echo "Creating sample input file..."
docker exec namenode mkdir -p /tmp/wordcount/input
docker exec namenode bash -c 'cat > /tmp/wordcount/input/input.txt << "EOF1"
hello world
hello hadoop
hadoop is big data
hello world hello
big data hadoop
world is big
hello hadoop world
big data big data
hadoop hello world
hello is big
EOF1'

# Upload input to HDFS
echo "Uploading input to HDFS..."
docker exec namenode hdfs dfs -mkdir -p /wordcount/input 2>/dev/null || true
docker exec namenode hdfs dfs -put /tmp/wordcount/input/input.txt /wordcount/input/

# List input files
echo ""
echo "Input files in HDFS:"
docker exec namenode hdfs dfs -ls /wordcount/input

# Wait for HDFS to be ready
echo ""
echo "Waiting for HDFS to be ready..."
sleep 5

# Run the WordCount job
echo ""
echo "Running WordCount MapReduce job..."
docker exec namenode hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar wordcount /wordcount/input /wordcount/output 2>&1

# Wait for job completion
echo ""
echo "Job completed. Checking results..."
sleep 5

# Display job result
echo ""
echo "WordCount Results:"
echo "===================="
docker exec namenode hdfs dfs -cat /wordcount/output/part-r-00000

echo ""
echo "==================================="
echo "WordCount execution completed!"
echo "==================================="
