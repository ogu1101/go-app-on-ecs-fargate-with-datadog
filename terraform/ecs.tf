resource "aws_ecs_cluster" "cluster" {
  name = "${var.env}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.service}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  container_definitions    = jsonencode([
    {
      "name": "${var.service}",
      "image": "${aws_ecr_repository.repository.repository_url}:${var.ver}",
      "cpu": 1024,
      "memory": 2048,
      "essential": true
      "environment": [
        {"name": "DD_API_KEY", "value": "${var.dd_api_key}"},
        {"name": "DD_SERVICE", "value": "${var.service}"},
        {"name": "DD_ENV",     "value": "${var.env}"},
        {"name": "DD_VERSION", "value": "${var.ver}"},
        {"name": "DBUSER",     "value": "${aws_rds_cluster.cluster.master_username}"},
        {"name": "DBPASS",     "value": "${aws_rds_cluster.cluster.master_password}"},
        {"name": "DBADDR",     "value": "${aws_rds_cluster.cluster.endpoint}:3306"}
      ],
      "dockerLabels": {
        "com.datadoghq.tags.service": "${var.service}",
        "com.datadoghq.tags.env"    : "${var.env}",
        "com.datadoghq.tags.version": "${var.ver}"
      },
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
          "options": {
            "awslogs-create-group": "true",
            "awslogs-group": "/ecs/${var.env}-fargate-task-definition",
            "awslogs-region": "${var.region}",
            "awslogs-stream-prefix": "ecs"
          }
      }
    },
    {
      "name": "datadog-agent",
      "image": "public.ecr.aws/datadog/agent:latest",
      "essential": true
      "environment": [
        {"name": "DD_API_KEY",           "value": "${var.dd_api_key}"},
        {"name": "ECS_FARGATE",          "value": "true"},
        {"name": "DD_SITE",              "value": "datadoghq.com"},
        {"name": "DD_APM_ENABLED",       "value": "true"},
        {"name": "DD_CONTAINER_EXCLUDE", "value": "name:datadog-agent"}
      ]
    }
  ])
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_service" "service" {
  name            = "${var.env}-ecs-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.service
    container_port   = 8080
  }

  network_configuration {
    subnets          = [aws_subnet.ecs_az_a.id, aws_subnet.ecs_az_c.id, aws_subnet.ecs_az_d.id]
    security_groups  = [aws_security_group.ecs.id]
  }
}
