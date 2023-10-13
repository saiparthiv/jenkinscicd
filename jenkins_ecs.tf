# Define the AWS provider and region
provider "aws" {
  region = "us-east-1"
}

# ECS Cluster
resource "aws_ecs_cluster" "jenkinscicd_cluster" {
  name = "jenkinscicd-cluster"
}

# Task Definition
resource "aws_ecs_task_definition" "jenkinscicd_task" {
  family                   = "jenkinscicd-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = <<DEFINITION
  [
    {
      "name": "jenkinscicd-app",
      "image": "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd:${data.aws_ecr_image.jenkinscicd_image.image_digest}",
      "cpu": 256,
      "memory": "512MB",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ]
  DEFINITION
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "jenkinscicd-ecs-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# ECS Service
resource "aws_ecs_service" "jenkinscicd_service" {
  name            = "jenkinscicd-service"
  cluster         = aws_ecs_cluster.jenkinscicd_cluster.id
  task_definition = aws_ecs_task_definition.jenkinscicd_task.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets = ["subnet-0c80f601a78574913"] # Replace with your subnet IDs
    security_groups = ["sg-008bb6cdd38c35d75"] # Replace with your security group IDs
  }
  depends_on = [aws_ecs_cluster.jenkinscicd_cluster]
}

# ECR Repository Data Source
data "aws_ecr_image" "jenkinscicd_image" {
  name = "jenkinscicd"
  image_digest = "latest"
  repository_name = "jenkinscicd"
}

# ECR Repository
resource "aws_ecr_repository" "jenkinscicd_repository" {
  name = "jenkinscicd"
}

# IAM Policy for ECS Execution Role
resource "aws_iam_policy" "ecs_execution_policy" {
  name = "jenkinscicd-ecs-execution-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:PutImage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach ECS Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
  role       = aws_iam_role.ecs_execution_role.name
}

# Output the ECS Cluster and Service details
output "ecs_cluster_id" {
  value = aws_ecs_cluster.jenkinscicd_cluster.id
}

output "ecs_service_name" {
  value = aws_ecs_service.jenkinscicd_service.name
}
