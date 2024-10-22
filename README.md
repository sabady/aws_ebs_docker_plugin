# Multi Arch Docker plugin that handles AWS EBS volume attachment to Docker Swarm Services

The plugin accepts the service name, creates an EBS volume, attaches it to the node, and creates a docker volume on it.
If the volume exists there will be a service label, and the plugin will attach it to the node.

## Docker Service Configuration
```
version: '3.8'
services:
  my-service:
    image: my-image
    volumes:
      - ebs-volume:/data
volumes:
  ebs-volume:
    driver: ebs-plugin
#    driver_opts:
#      volume_id: vol-12345678 # Example volume ID to attach
```

## IAM Role for EBS Permissions
```
{
    "Effect": "Allow",
    "Action": [
        "ec2:DescribeVolumes",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:CreateVolume",
        "ec2:DeleteVolume",
        "ec2:DescribeInstances"
    ],
    "Resource": "*"
}
```
