#!/bin/bash

# Configure ECS agent
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_LOGGING=true >> /etc/ecs/ecs.config

# Update system
yum update -y

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Install useful tools
yum install -y htop docker

# Configure docker
usermod -a -G docker ec2-user
systemctl enable docker
systemctl start docker

# Start ECS agent
start ecs