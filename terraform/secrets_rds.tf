# ------------------------------------------------------------------ credentials
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?" # excludes / @ " and space, which RDS rejects
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db-credentials"
  description             = "RDS MySQL credentials for ${local.name}"
  recovery_window_in_days = var.db_skip_final_snapshot ? 0 : 7
}

# ------------------------------------------------------------------ RDS
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id

  tags = { Name = "${local.name}-db-subnets" }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 3
  storage_type          = "gp3"
  storage_encrypted     = true # encryption at rest (AWS-managed key)

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_skip_final_snapshot ? null : "${local.name}-final"

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
}

# Secret value written after RDS exists so it can carry the endpoint.
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}
