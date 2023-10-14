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
  name = "my-service"
  cluster = aws_ecs_cluster.jenkinscicd_cluster.name
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count = 1
}