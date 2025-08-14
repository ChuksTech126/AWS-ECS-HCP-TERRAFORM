terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Security Group
resource "aws_security_group" "ecs_ec2_sg" {
  name        = "ecs-ec2-${var.environment}"
  description = "Security group for ECS EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecs-ec2-${var.environment}"
    Environment = var.environment
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_ec2_role" {
  name = "ecs-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role_policy" {
  role       = aws_iam_role.ecs_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_ec2_profile" {
  name = "ecs-ec2-profile-${var.environment}"
  role = aws_iam_role.ecs_ec2_role.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = 7
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster-${var.environment}"

  tags = {
    Name        = "${var.app_name}-cluster-${var.environment}"
    Environment = var.environment
  }
}

# Launch Template
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-template-${var.environment}-"
  description   = "Launch template for ECS EC2 instances"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ecs_ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_ec2_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    cluster_name = aws_ecs_cluster.main.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "ecs-instance-${var.environment}"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg-${var.environment}"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = []
  health_check_type   = "EC2"
  
  min_size         = 1
  max_size         = var.ec2_instance_count + 2
  desired_capacity = var.ec2_instance_count

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  protect_from_scale_in = false

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Capacity Provider
resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
  name = "ec2-capacity-provider-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
    
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
    
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = [aws_ecs_capacity_provider.ec2_capacity_provider.name]
  
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ec2_capacity_provider.name
  }
}

# Task Definition
resource "aws_ecs_task_definition" "web_app" {
  family                = "${var.app_name}-${var.environment}"
  network_mode          = "bridge"
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "web-container"
      image = var.container_image
      
      memory = var.container_memory
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "web_service" {
  name            = "${var.app_name}-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_app.arn
  desired_count   = var.container_count
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2_capacity_provider.name
    weight           = 100
  }

  
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_autoscaling_group.ecs_asg
  ]

  tags = {
    Name        = "${var.app_name}-service-${var.environment}"
    Environment = var.environment
  }
}
