# Docker Service Configuration
```
version: '3.8'
services:
  my-service:
    image: my-image
    volumes:
      - my-ebs-volume:/data
volumes:
  my-ebs-volume:
    driver: my-ebs-plugin
    driver_opts:
      volume_id: vol-12345678 # Example volume ID to attach
```

# IAM Role for EBS Permissions
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
