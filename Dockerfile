# Use Eclipse Temurin (OpenJDK 8) with Debian base
FROM eclipse-temurin:8-jdk

# Set Hadoop version and download URL
ENV HADOOP_VERSION=3.4.2
ENV HADOOP_URL=https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

# Install Hadoop and dependencies
RUN apt-get update && apt-get install -y \
    wget \
    openssh-server \
    bash \
    net-tools \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q ${HADOOP_URL} \
    && tar -xzf hadoop-${HADOOP_VERSION}.tar.gz \
    && rm hadoop-${HADOOP_VERSION}.tar.gz \
    && mv hadoop-${HADOOP_VERSION} /opt/hadoop

# Create SSH privilege separation directory
RUN mkdir -p /run/sshd

# Set up environment variables
ENV JAVA_HOME=/opt/java/openjdk
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Allow running Hadoop as root
ENV HDFS_NAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

# Configure SSH for passwordless access with shared key
RUN mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && echo "Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null" > /etc/ssh/ssh_config \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Generate a single shared SSH key for all nodes
RUN ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa \
    && cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys \
    && chmod 0600 /root/.ssh/authorized_keys /root/.ssh/id_rsa

# Create hadoop configuration directory
RUN mkdir -p /opt/hadoop/etc/hadoop

# Copy custom configuration
COPY *.xml /opt/hadoop/etc/hadoop/
COPY hadoop-env.sh /opt/hadoop/etc/hadoop/hadoop-env.sh
COPY workers /opt/hadoop/etc/hadoop/workers

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /opt/hadoop

# Expose ports
EXPOSE 9870 9871 8088 19888 9000 9001

# Use entrypoint to properly initialize
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
