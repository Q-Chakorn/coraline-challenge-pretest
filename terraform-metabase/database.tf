resource "aws_security_group" "database" {
  name        = "${local.name}-database-sg"
  description = "Only Metabase ECS tasks may connect to PostgreSQL"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL from Metabase tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.metabase.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-database-sg" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, { Name = "${local.name}-db-subnets" })
}

resource "aws_db_instance" "metabase" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_encrypted     = true

  db_name             = "metabase"
  username            = "metabase"
  port                = 5432
  multi_az            = false
  publicly_accessible = false

  # AWS generates and stores the master password in Secrets Manager.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]

  backup_retention_period = 7
  deletion_protection     = false # Set true after confirming the deployment.
  skip_final_snapshot     = true  # Change to false for a production teardown policy.

  tags = merge(local.common_tags, { Name = "${local.name}-postgres" })
}
