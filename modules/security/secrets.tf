# =============================================================================
# modules/security/secrets.tf
# 2 secrets AWS Secrets Manager : mot de passe DB + mot de passe admin Nextcloud.
# Generes aleatoirement via le provider "random".
# =============================================================================
# Ressources a declarer :
#
#   - random_password                "db"    (length = 24, special = false,
#                                              override_special = "")
#                                             (RDS PG n accepte pas certains caracteres speciaux)
#   - random_password                "admin" (length = 20, special = true)
#
#   - aws_secretsmanager_secret         "db_password"
#                                         - name        = "${local.name_prefix}-db-password"
#                                         - kms_key_id  = aws_kms_key.main.arn
#                                         - recovery_window_in_days = 0  (dev — destroy immediat)
#
#   - aws_secretsmanager_secret_version "db_password"
#                                         - secret_id     = ...db_password.id
#                                         - secret_string = random_password.db.result
#
#   - aws_secretsmanager_secret         "admin_password"  (idem db)
#   - aws_secretsmanager_secret_version "admin_password"  (idem db)
#
# 🟡 recovery_window_in_days :
#   - 0 en dev : permet destroy immediat (sinon le nom est "reserve" 7-30 jours
#     et on ne peut pas recreer un secret avec le meme nom).
#   - 30 en prod : fenetre de recuperation contre suppression accidentelle.
# =============================================================================

resource "random_password" "db" {
  length           = 24
  special          = false
  override_special = ""
}

resource "random_password" "admin" {
  length  = 20
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}-db-password"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "admin_password" {
  name                    = "${local.name_prefix}-admin-password"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "admin_password" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = random_password.admin.result
}
