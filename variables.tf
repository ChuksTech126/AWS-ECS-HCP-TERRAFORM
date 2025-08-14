variable "environment" {
  description = "Environment name (production, staging, dev)"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "web-app"
}

variable "container_count" {
  description = "Number of containers to run"
  type        = number
  default     = 2
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances in the cluster"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "container_image" {
  description = "Docker image to deploy"
  type        = string
  default     = "nginx:latest"
}

variable "container_memory" {
  description = "Memory allocation for container"
  type        = number
  default     = 256
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}