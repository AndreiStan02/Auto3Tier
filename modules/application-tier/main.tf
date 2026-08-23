data "aws_region" "current" {}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_sg" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb_sg.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "tasks_sg" {
  name   = "${var.name}-tasks-sg"
  vpc_id = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-tasks-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  ip_protocol                  = "tcp"
}

# Needed for ECR image pulls and CloudWatch, both via the NAT gateway.
resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.tasks_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Lives here, not in data-tier — this is what breaks the dependency cycle.
resource "aws_vpc_security_group_ingress_rule" "db_from_tasks" {
  security_group_id            = var.db_security_group_id
  referenced_security_group_id = aws_security_group.tasks_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "main" {
  name        = "${var.name}-tg"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate awsvpc networking

  # Default is 300s, which makes every deployment drag.
  deregistration_delay = 30

  health_check {
    path                = var.health_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(var.tags, { Name = "${var.name}-listener" })
}

resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.name}-app-log-group" })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed policy above does NOT grant access to your secret.
resource "aws_iam_role_policy" "execution_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}

# Separate from the execution role: this is what the app itself uses at
# runtime. Empty by default — add S3, SQS etc. as the app needs them.
resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-ecs-cluster"

  tags = merge(var.tags, { Name = "${var.name}-ecs-cluster" })
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.name}-ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = "${var.name}-container"
    image     = var.backend_image
    essential = true

    portMappings = [{
      containerPort = var.backend_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "DB_HOST"
        value = var.db_endpoint
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      },
      {
        name  = "PORT"
        value = tostring(var.backend_port)
      }
    ]

    secrets = [
      {
        name      = "DB_USERNAME"
        valueFrom = "${var.db_secret_arn}:username::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${var.db_secret_arn}:password::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app_log_group.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "${var.name}-ecs"
      }
    }
  }])

  tags = merge(var.tags, { Name = "${var.name}-task" })
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.name}-ecs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.tasks_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.name}-container"
    container_port   = var.backend_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener.http]
}
