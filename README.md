# Hadoop Multi-Node Cluster with Docker

This project provides a complete Hadoop multi-node cluster setup using Docker containers.

## Architecture

```
+------------------+     +------------------+     +------------------+
|    NameNode      |     |   ResourceManager|     |                  |
|   (Container)    |     |   (Container)    |     |                  |
|   HDFS Master    |     |   YARN Master    |     |   Host Machine   |
|   Port: 9870     |     |   Port: 8088     |     |                  |
+--------+---------+     +--------+---------+     +--------+---------
         |                        |                        |
         +------------------------+                        |
                  |                                        |
                  v                                        v
+--------+------------------+     +------------------+--------+
|           DataNode 1        |     |      DataNode 2         |
|      (Container with        |     |   (Container with       |
|       NodeManager 1)        |     |    NodeManager 2)       |
|   Ports: 9864, 8042         |     |   Ports: 9865, 8043      |
+---------------------------+     +---------------------------+
```

## Components

| Component | Count | Description |
|-----------|-------|-------------|
| NameNode  | 1     | HDFS master that manages file system metadata |
| DataNode  | 2     | HDFS workers that store actual data |
| ResourceManager | 1 | YARN master that manages cluster resources |
| NodeManager | 2 | YARN workers that manage task execution |

## Prerequisites

- Docker Engine 19.03 or higher
- Docker Compose 1.29 or higher
- At least 4GB of available RAM

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# 1. Build the Docker image
docker build -t hadoop-base:latest .

# 2. Start the cluster
docker-compose up -d

# 3. Wait for services to initialize (about 30 seconds)
sleep 30

# 4. Check cluster status
docker exec namenode hdfs dfsadmin -report
```

### Option 2: Using the Setup Script

```bash
# Make scripts executable
chmod +x setup-cluster.sh stop-cluster.sh run-wordcount.sh

# Start the cluster
./setup-cluster.sh
```

## Running WordCount Program

### Method 1: Using the Script

```bash
./run-wordcount.sh
```

### Method 2: Manual Execution

```bash
# Connect to namenode container
docker exec -it namenode bash

# Inside the container:
# Create input directory in HDFS
hdfs dfs -mkdir -p /wordcount/input

# Create sample input
mkdir -p /tmp/wordcount/input
cat > /tmp/wordcount/input/input.txt << 'EOF'
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
EOF

# Upload input to HDFS
hdfs dfs -put /tmp/wordcount/input/input.txt /wordcount/input/

# Run WordCount
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount /wordcount/input /wordcount/output

# View results
exit
```

### Method 3: From Host Machine (with JRE)

```bash
# Upload input file
docker exec namenode hdfs dfs -mkdir -p /wordcount/input
docker exec -it namenode bash -c "cat > /tmp/input.txt << 'EOF'
hello world
hello hadoop
EOF
hdfs dfs -put /tmp/input.txt /wordcount/input/"

# Run job
docker exec namenode hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount /wordcount/input /wordcount/output

# View results
docker exec namenode hdfs dfs -cat /wordcount/output/part-r-00000
```

## Managing the Cluster

### View Container Status

```bash
docker-compose ps
# or
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Check Logs

```bash
# All containers
docker-compose logs

# Specific container
docker logs namenode
docker logs datanode1
```

### Access a Container Shell

```bash
docker exec -it namenode bash
docker exec -it datanode1 bash
```

### Stop the Cluster

```bash
# Using docker-compose
docker-compose down

# Using the script
./stop-cluster.sh
```

### Remove Everything (Clean Slate)

```bash
docker-compose down -v
docker rmi hadoop-base:latest
```

## HDFS Commands

### Basic File Operations

```bash
# List files
docker exec namenode hdfs dfs -ls /

# Make directory
docker exec namenode hdfs dfs -mkdir /test

# Upload file
docker exec namenode hdfs dfs -put localfile.txt /test/

# Download file
docker exec namenode hdfs dfs -get /test/localfile.txt ./localfile.txt

# View file content
docker exec namenode hdfs dfs -cat /test/file.txt

# Remove file/directory
docker exec namenode hdfs dfs -rm -r /test

# Check disk usage
docker exec namenode hdfs dfs -du -h /
```

### Cluster Report

```bash
docker exec namenode hdfs dfsadmin -report
```

## YARN Commands

### Check Applications

```bash
# List running applications
docker exec resourcemanager yarn application -list

# Kill an application
docker exec resourcemanager yarn application -kill <application_id>
```

### Node Status

```bash
docker exec resourcemanager yarn node -list
```

## Web Interfaces

| Service | URL | Description |
|---------|-----|-------------|
| NameNode | http://localhost:9870 | HDFS status and file browser |
| ResourceManager | http://localhost:8088 | YARN cluster management |
| DataNode1 | http://localhost:9864 | DataNode1 status |
| DataNode2 | http://localhost:9865 | DataNode2 status |

## Configuration Files

All configuration files are mounted in the containers and can be modified:

| File | Location | Description |
|------|----------|-------------|
| core-site.xml | /opt/hadoop/etc/hadoop/ | Core Hadoop configuration |
| hdfs-site.xml | /opt/hadoop/etc/hadoop/ | HDFS configuration |
| yarn-site.xml | /opt/hadoop/etc/hadoop/ | YARN configuration |
| mapred-site.xml | /opt/hadoop/etc/hadoop/ | MapReduce configuration |
| workers | /opt/hadoop/etc/hadoop/ | List of worker nodes |

## Troubleshooting

### Containers won't start

```bash
# Check container logs
docker logs namenode

# Check if ports are in use
netstat -tlnp | grep -E '9870|8088|9000'
```

### NameNode not starting

```bash
# Check for port conflicts
docker rm namenode
docker-compose up -d namenode
```

### DataNodes not connecting to NameNode

```bash
# Verify network connectivity
docker exec datanode1 ping -c 3 namenode

# Check if NameNode is running
docker exec namenode jps
```

### Clear all data and restart

```bash
docker-compose down -v
docker volume rm hadoop-namenode-data hadoop-datanode1-data hadoop-datanode2-data
docker-compose up -d
```

### Check SSH connectivity inside containers

```bash
docker exec namenode ssh -o StrictHostKeyChecking=no datanode1 "echo 'Connected'"
```

## Performance Tuning

To adjust resource allocation, modify the following in docker-compose.yml:

```yaml
# Increase container memory
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 2G
```

Or modify YARN configuration in yarn-site.xml:

```xml
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
</property>
```

## Notes

- This setup is for development/testing purposes only
- SSH is configured for passwordless access between containers
- HDFS replication factor is set to 2
- All containers run as root for simplicity
- Data is persisted in Docker volumes

## License

This project is provided for educational and development purposes.
