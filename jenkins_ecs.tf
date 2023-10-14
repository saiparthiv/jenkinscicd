provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_cluster" "jenkinscicd_cluster" {
  name = "jenkinscicd-cluster"
}

resource "aws_ecs_task_definition" "my_task" {
  family = "my-task"
  network_mode = "awsvpc"

  cpu = "256"
  memory = "512"  

  container_definitions = <<EOF
[
  {
    "name": "jenkinscicd-app",
    "image": "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd:latest",
    "portMappings": [
      {
        "containerPort": 85,
        "hostPort": 85
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "jenkinscicd_service" {
  name = "jenkinscicd-service"
  cluster = aws_ecs_cluster.jenkinscicd_cluster.name
  task_definition = aws_ecs_task_definition.my_task.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets = ["subnet-0c80f601a78574913"] # Replace with your subnet IDs
    security_groups = ["sg-008bb6cdd38c35d75"] # Replace with your security group IDs
  }
  desired_count = 1
  depends_on = [aws_ecs_cluster.jenkinscicd_cluster]
}