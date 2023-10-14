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
      "image": "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd:${data.aws_ecr_image.jenkinscicd_image.image_tag}",
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
  desired_count = 1
  depends_on = [aws_ecs_cluster.jenkinscicd_cluster]
}

# ECR Repository Data Source
data "aws_ecr_image" "jenkinscicd_image" {
  repository_name = "jenkinscicd"
  image_tag = "latest"
}


# Define the list of Availability Zones where you want to create subnets
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Create subnets in different Availability Zones
resource "aws_subnet" "example" {
  count = length(var.availability_zones)
  
  vpc_id                  = "vpc-08e4f792b45a68d24"
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = "172.31.${count.index}.0/24"  # Customize the CIDR block range
  map_public_ip_on_launch = true
}

# Create an Application Load Balancer
resource "aws_lb" "web" {
  name               = "my-web-lb"
  internal           = false
  load_balancer_type = "application"
  
  # Use the created subnets
  subnets = aws_subnet.example[*].id
  
  enable_deletion_protection = false
}

# Create an ALB listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
    }
  }
}

# Create a Target Group
resource "aws_lb_target_group" "jenkinscicd_target_group" {
  name     = "jenkinscicd-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-08e4f792b45a68d24" # Use your VPC ID
  health_check {
    path                = "/" # Replace with an appropriate health check path
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
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
