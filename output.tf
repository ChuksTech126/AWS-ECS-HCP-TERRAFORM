output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.web_service.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.web_app.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs_asg.name
}

output "ec2_security_group_id" {
  description = "Security Group ID for EC2 instances"
  value       = aws_security_group.ecs_ec2_sg.id
}

output "access_instructions" {
  description = "Instructions to access your application"
  value = <<-EOT
    Your ECS cluster is running!
    
    To find your application:
    1. Go to AWS Console → ECS → Clusters → ${aws_ecs_cluster.main.name}
    2. Click on the service → Tasks tab
    3. Click on a running task
    4. Find the public IP and dynamic port
    5. Visit http://PUBLIC-IP:PORT
  EOT
}