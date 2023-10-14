provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "my_repository" {
  name = "my-repository"
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

resource "aws_ecs_task_definition" "my_task" {
  family = "my-task"
  network_mode = "awsvpc"

  container_definitions = <<EOF
[
  {
    "name": "my-container",
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

resource "aws_ecs_service" "my_service" {
  name = "my-service"
  cluster = aws_ecs_cluster.my_cluster.name
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count = 1
}