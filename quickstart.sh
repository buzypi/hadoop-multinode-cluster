#!/bin/bash
# Quick Start Script - One command to set up everything!

set -e

echo "=========================================="
echo "  Hadoop Multi-Node Cluster Quick Start"
echo "=========================================="
echo ""

# Check for running containers and clean up
cleanup() {
    echo "Cleaning up existing containers..."
    docker rm -f namenode datanode1 datanode2 2>/dev/null || true
    docker network rm hadoop-network 2>/dev/null || true
}

# Build the Docker image
build_image() {
    echo "Building Hadoop Docker image..."
    docker build -t hadoop-base:latest .
    echo "Image built successfully!"
}

# Start the cluster using docker-compose
start_cluster() {
    echo ""
    echo "Starting Hadoop cluster..."
    docker-compose up -d
    echo "Cluster containers started."
}

# Wait for services to be ready
wait_for_services() {
    echo ""
    echo "Waiting for services to initialize (this may take 60-90 seconds)..."
    
    local max_attempts=90
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if NameNode is responding
        if docker exec namenode hdfs dfsadmin -report > /dev/null 2>&1; then
            echo "Services are ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo "  Attempt $attempt/$max_attempts - waiting..."
        sleep 2
    done
    
    echo "Warning: Services may not be fully ready yet. Checking status..."
}

# Run WordCount example
run_wordcount() {
    echo ""
    echo "Running WordCount example..."
    
    # Create sample input
    docker exec namenode bash -c 'cat > /tmp/wordcount/input/input.txt << "INPUTEOF"
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
INPUTEOF'

    # Upload to HDFS
    docker exec namenode hdfs dfs -mkdir -p /wordcount/input 2>/dev/null || true
    docker exec namenode hdfs dfs -put /tmp/wordcount/input/input.txt /wordcount/input/
    
    echo "Input uploaded to HDFS."
    
    # Run the job
    docker exec namenode hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar wordcount /wordcount/input /wordcount/output
}

# Display status and information
display_status() {
    echo ""
    echo "=========================================="
    echo "  Cluster Status"
    echo "=========================================="
    echo ""
    
    echo "Container Status:"
    docker ps --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode" || true
    
    echo ""
    echo "Web Interfaces:"
    echo "  HDFS NameNode UI:       http://localhost:9870"
    echo "  YARN ResourceManager:   http://localhost:8088"
    
    echo ""
    echo "HDFS Cluster Report:"
    docker exec namenode hdfs dfsadmin -report 2>/dev/null | head -20 || echo "Report not yet available"
    
    echo ""
    echo "WordCount Results:"
    docker exec namenode hdfs dfs -cat /wordcount/output/part-r-00000 2>/dev/null || echo "Results not yet available"
    
    echo ""
    echo "=========================================="
    echo "  Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Useful Commands:"
    echo "  Check cluster:   docker exec namenode hdfs dfsadmin -report"
    echo "  List files:      docker exec namenode hdfs dfs -ls /"
    echo "  Stop cluster:    docker-compose down"
    echo ""
}

# Main execution
main() {
    cleanup
    build_image
    start_cluster
    wait_for_services
    run_wordcount
    display_status
}

# Parse arguments
case "${1:-quickstart}" in
    quickstart)
        main
        ;;
    build)
        build_image
        ;;
    start)
        start_cluster
        ;;
    stop)
        echo "Stopping cluster..."
        docker-compose down
        ;;
    clean)
        cleanup
        echo "Cleanup complete."
        ;;
    status)
        display_status
        ;;
    wordcount)
        run_wordcount
        ;;
    *)
        echo "Usage: $0 {quickstart|build|start|stop|clean|status|wordcount}"
        echo ""
        echo "  quickstart - Build, start cluster, and run WordCount"
        echo "  build      - Build Docker image only"
        echo "  start      - Start the cluster"
        echo "  stop       - Stop the cluster"
        echo "  clean      - Remove all containers and network"
        echo "  status     - Display cluster status"
        echo "  wordcount  - Run WordCount example"
        exit 1
        ;;
esac
