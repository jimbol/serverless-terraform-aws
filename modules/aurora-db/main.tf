
# Dont forget to add rds and secrets security policy to lambda
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = var.database_subnets

  tags = {
    Name = "My DB subnet group"
  }
}

module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"

  name              = "${var.env}-postgresql"
  engine            = "aurora-postgresql"
  engine_mode       = "serverless"
  storage_encrypted = true

  vpc_id                = var.vpc_id
  subnets               = var.database_subnets
  allowed_cidr_blocks   = var.private_subnets_cidr_blocks
  create_security_group = true
  create_db_subnet_group = false
  db_subnet_group_name = aws_db_subnet_group.default.id

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  db_parameter_group_name         = aws_db_parameter_group.example_postgresql.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.example_postgresql.id

  enable_http_endpoint = true

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 16
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
}

resource "aws_db_parameter_group" "example_postgresql" {
  name        = "${var.env}-aurora-db-postgres-parameter-group"
  family      = "aurora-postgresql10"
  description = "${var.env}-aurora-db-postgres-parameter-group"
}

resource "aws_rds_cluster_parameter_group" "example_postgresql" {
  name        = "${var.env}-aurora-postgres-cluster-parameter-group"
  family      = "aurora-postgresql10"
  description = "${var.env}-aurora-postgres-cluster-parameter-group"
}

# Creating a AWS secret for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret" "db_pass" {
  name = "AuroraDatabasePassword"
}

# Creating a AWS secret versions for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id = aws_secretsmanager_secret.db_pass.id
  secret_string = <<EOF
   {
    "username": "root",
    "password": "${module.aurora_postgresql.cluster_master_password}"
   }
EOF
}
