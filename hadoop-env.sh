#!/bin/bash
# Hadoop Environment Configuration

# Use Eclipse Temurin JAVA_HOME
export JAVA_HOME=/opt/java/openjdk
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Hadoop Heap Size
export HADOOP_HEAPSIZE=1024
export HADOOP_NAMENODE_HEAPSIZE=512
export HADOOP_DATANODE_HEAPSIZE=512

# YARN Resource Manager
export YARN_HEAPSIZE=1024

# Log directories (use HADOOP_LOG_DIR only to avoid warnings)
export HADOOP_LOG_DIR=/opt/hadoop/logs

# PID directories (use HADOOP_PID_DIR only to avoid warnings)
export HADOOP_PID_DIR=/tmp

# Create log and PID directories
mkdir -p $HADOOP_LOG_DIR

# SSH configuration
export SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Allow running Hadoop as root
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

# Hadoop classpath for MapReduce
export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/yarn/lib/*

# Additional classpath for YARN containers
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
