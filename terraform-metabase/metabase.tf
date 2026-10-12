resource "aws_security_group" "load_balancer" {
  name        = "${local.name}-alb-sg"
  description = "Public web access to Metabase"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "metabase" {
  name        = "${local.name}-metabase-sg"
  description = "Metabase containers accept traffic only from the load balancer"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Metabase web traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-metabase-sg" })
}

resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.common_tags, { Name = "${local.name}-alb" })
}

resource "aws_lb_target_group" "metabase" {
  name        = "${local.name}-metabase"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/api/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, { Name = "${local.name}-metabase" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase.arn
  }
}

resource "aws_cloudwatch_log_group" "metabase" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30

  tags = local.common_tags
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_database_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.metabase.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "read_database_secret" {
  name   = "read-database-secret"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.read_database_secret.json
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "metabase" {
  family                   = "${local.name}-metabase"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.metabase_cpu
  memory                   = var.metabase_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "metabase"
    image     = var.metabase_image
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "MB_DB_TYPE", value = "postgres" },
      { name = "MB_DB_DBNAME", value = "metabase" }
    ]

    # Each value is read by ECS at startup. Passwords are never written to Terraform files.
    secrets = [
      { name = "MB_DB_USER", valueFrom = "${aws_db_instance.metabase.master_user_secret[0].secret_arn}:username::" },
      { name = "MB_DB_PASS", valueFrom = "${aws_db_instance.metabase.master_user_secret[0].secret_arn}:password::" },
      { name = "MB_DB_HOST", valueFrom = "${aws_db_instance.metabase.master_user_secret[0].secret_arn}:host::" },
      { name = "MB_DB_PORT", valueFrom = "${aws_db_instance.metabase.master_user_secret[0].secret_arn}:port::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.metabase.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "metabase"
      }
    }
  }])

  tags = local.common_tags
}

resource "aws_ecs_service" "metabase" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.metabase.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.metabase.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.metabase.arn
    container_name   = "metabase"
    container_port   = 3000
  }

  # Ensure the execution role can read the generated RDS secret before a task starts.
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.task_execution,
    aws_iam_role_policy.read_database_secret
  ]

  tags = local.common_tags
}
