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

  cpu = "256"
  memory = "512"

  container_definitions = <<DEFINITION
  [
    {
      "name": "jenkinscicd-app",
      "image": "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd:latest",
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 85,
          "hostPort": 85
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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_alb" "jenkinscicd_alb" {
  name = "jenkinscicd-alb"
  subnets = ["subnet-011a25a8ff709d9fe", "subnet-073a0165c5c39bdd1"] # Replace with your subnet IDs
  security_groups = ["sg-008bb6cdd38c35d75"] # Replace with your security group IDs
}

resource "aws_alb_target_group" "jenkinscicd_target_group" {
  name = "jenkinscicd-target-group"
  port = 85
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
}

resource "aws_alb_listener" "jenkinscicd_listener" {
  load_balancer_arn = aws_alb.jenkinscicd_alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.jenkinscicd_target_group.arn
  }
}

resource "aws_alb_listener_rule" "jenkinscicd_listener_rule" {
  listener_arn = aws_alb_listener.jenkinscicd_listener.arn
  priority = 1
  condition {
    path_pattern {
      values = ["/"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_alb_target_group.jenkinscicd_target_group.arn
  }
}

# ECS Service
resource "aws_ecs_service" "jenkinscicd_service" {
  name            = "jenkinscicd-service"
  cluster         = aws_ecs_cluster.jenkinscicd_cluster.id
  task_definition = aws_ecs_task_definition.jenkinscicd_task.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets = ["subnet-011a25a8ff709d9fe"] # Replace with your subnet IDs
    security_groups = ["sg-008bb6cdd38c35d75"] # Replace with your security group IDs
  }
  desired_count = 1
  depends_on = [aws_ecs_cluster.jenkinscicd_cluster]
}

# ECR Repository Data Source
data "aws_ecr_image" "jenkinscicd_image" {
  repository_name = "jenkinscicd"
  image_tag = "latest"
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

# Output the Load Balancer URL
output "jenkinscicd_load_balancer_url" {
  value = aws_alb.jenkinscicd_alb.dns_name
}
