#!/bin/bash

# EBS volume management script for AWS

SERVICE_NAME=$1

AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_PROFILE=${AWS_PROFILE:-"default"}
VOLUME_SIZE=${VOLUME_SIZE:-"10"}  # Default volume size in GiB

# Function to check if volume exists
check_volume_exists() {
    local volume_id="$1"
    volume_id=$(aws ec2 describe-volumes --filters Name=tag:Name,Values=${SERVICE_NAME} --query "Volumes[0].VolumeId" --region ${AWS_REGION} --profile ${AWS_PROFILE} --output text)
    if [ "$volume_id" == "None" ]; then
        echo "No existing EBS volume found. Creating a new one..."
        volume_id=$(create_ebs_volume "${SERVICE_NAME}")
    else
        echo "Found existing EBS volume: $volume_id"
    fi 

    echo "$volume_id"
}

# Function to create EBS volume
create_ebs_volume() {
    echo "Creating a new EBS volume for service ${SERVICE_NAME}..."
    volume_id=$( \
    aws ec2 create-volume \
        --volume-type gp3 \
        --size "$VOLUME_SIZE" \
        --availability-zone $(aws ec2 describe-availability-zones --query "AvailabilityZones[0].ZoneName" --output text --region ${AWS_REGION}) \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=${SERVICE_NAME}}]" \
        --region ${AWS_REGION} --profile ${AWS_PROFILE} \
        --query "VolumeId" \
        --output text \
    )

    echo "$volume_id"  # Return the volume ID
}

# Function to attach volume
attach_ebs_volume() {
    local volume_id=$1
    local instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    echo "Attaching volume ${volume_id} to instance ${instance_id}..."
    aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/xvdf --region ${AWS_REGION} --profile ${AWS_PROFILE}
    # Store the volume ID
    docker service update --label-add ebs_volume_id="$volume_id" ${SERVICE_NAME}
}

# Functions to create a Docker volume using the EBS volume_id
get_docker_volume_name() {
    echo "Retrieving Docker volume name from service configuration..."
    DOCKER_VOLUME_NAME=$(docker service inspect --format '{{range .Spec.TaskTemplate.Containers}}{{.Mounts}}{{end}}' "$SERVICE_NAME" | grep -oP '(?<=Source:).*?(?=,)' | tr -d ' ')
    
    if [ -z "$DOCKER_VOLUME_NAME" ]; then
        echo "No Docker volume name found in service configuration. Exiting..."
        exit 1
    fi
    
    echo "Docker volume name retrieved: $DOCKER_VOLUME_NAME"
}

create_docker_volume() {
    local volume_id="$1"

    # Create a Docker volume and link it to the EBS volume
    echo "Creating Docker volume linked to EBS volume $volume_id..."
    docker volume create --driver=ebs-plugin --opt volume_id="$volume_id" "$DOCKER_VOLUME_NAME"
    echo "Created Docker volume: $DOCKER_VOLUME_NAME"
}

attach_docker_volume_to_service() {
    echo "Attaching Docker volume $DOCKER_VOLUME_NAME to service $SERVICE_NAME..."
    docker service update --mount-add type=volume,source="$DOCKER_VOLUME_NAME",target=/path/in/container "$SERVICE_NAME"
    echo "Docker volume $DOCKER_VOLUME_NAME attached to service $SERVICE_NAME."
}

# Function to detach volume
detach_ebs_volume() {
  local volume_id="$1"
  local instance_id="$2"

  echo "Detaching volume $volume_id from instance $instance_id..."
  aws ec2 detach-volume --volume-id "$volume_id" --region "$AWS_REGION" --force
}

# Function to get the volume ID from service labels
get_ebs_volume_id_from_labels() {
    local service_name="$1"
    docker service inspect --format '{{ .Spec.TaskTemplate.Containers }}' "$service_name" | grep -oP 'ebs_volume_id=\K[^ ]+'
}

handle_node_shutdown() {
  local instance_id
  instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

  echo "Handling shutdown for instance $instance_id..."

  # Detach all attached volumes (if necessary)
  for volume_id in $(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values="$instance_id" --query "Volumes[].VolumeId" --output text); do
    detach_ebs_volume "$volume_id" "$instance_id"
  done
}

# Main logic
echo "Managing EBS volumes for service: ${SERVICE_NAME}..."

# Trap termination signals
trap 'handle_node_shutdown' SIGTERM SIGINT

volume_id=$(check_volume_exists)

if [ "$volume_id" = "None" ]; then
    # Create a new EBS volume if it doesn't exist
    create_volume
    volume_id=$(check_volume_exists)
    attach_volume "$volume_id"
else
    echo "Volume ${volume_id} already exists, attaching it to the instance..."
    attach_volume "$volume_id"
fi

while true; do
  # Check for node shutdown signal (this could be an external signal or a check)
  if [[ "$(systemctl is-active docker)" == "inactive" ]]; then
    handle_node_shutdown
    break
  fi

  # Manage services
  manage_service

  # Sleep or wait for a specific event before checking again
  sleep 10
done
echo "EBS volume management complete."
