# Dockerfile
FROM alpine:3.18

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3 \
    py3-pip \
    && pip3 install awscli

# Add AWS CLI completion (optional)
RUN mkdir /workdir

# Add volume management script
COPY ebs_manager.sh /usr/local/bin/ebs_manager.sh
RUN chmod +x /usr/local/bin/ebs_manager.sh

# Plugin configuration for Docker
COPY config.json /etc/docker/plugin/config.json

# Set entrypoint to manage EBS volumes
ENTRYPOINT ["/usr/local/bin/ebs_manager.sh"]
