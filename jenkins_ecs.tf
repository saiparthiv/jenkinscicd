# Define the AWS provider and region
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Define an Internet Gateway resource
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Attach the Internet Gateway to the VPC
resource "aws_internet_gateway_attachment" "main_igw_attachment" {
  vpc_id             = aws_vpc.main.id
  internet_gateway_id = aws_internet_gateway.main.id
}


# Create subnets within the VPC
resource "aws_subnet" "subnet_a" {
  count = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.${count.index * 16}/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Define a security group for your ECS tasks
resource "aws_security_group" "ecs_security_group" {
  name_prefix = "ecs-security-group-"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Define inbound and outbound rules as needed
  # For example, allow incoming traffic on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust the CIDR block as needed
  }

  # You can define more rules as required.
}

# Define a route table for your subnets
resource "aws_route_table" "subnet_route_table" {
  vpc_id = aws_vpc.main.id

  # Define routes as needed, such as a route to an internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id  # You'll need to define an Internet Gateway resource
  }
}

# Associate your subnets with the route table
resource "aws_route_table_association" "subnet_route_association" {
  count          = length(aws_subnet.subnet_a)
  subnet_id      = aws_subnet.subnet_a[count.index].id
  route_table_id = aws_route_table.subnet_route_table.id
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

resource "aws_alb" "jenkinscicd_alb" {
  name = "jenkinscicd-alb"
  subnets = aws_subnet.subnet_a[*].id
  security_groups = [aws_security_group.ecs_security_group.id]  # Use the security group created earlier
}

resource "aws_alb_target_group" "jenkinscicd_target_group" {
  name = "jenkinscicd-target-group"
  port = 80
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
    subnets = aws_subnet.subnet_a[*].id
    security_groups = [aws_security_group.ecs_security_group.id]  # Use the security group created earlier
    assign_public_ip = "true"
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
        "ecr:BatchGetImage",
        "ecr:ListImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:PutImage",
        "ecr:*",
        "ecr-public:*"
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
