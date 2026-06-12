# =============================================================================
# modules/data/main.tf
# ROLE 4 (Data Engineer) — data sources + ressources partagees du module.
# =============================================================================

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}