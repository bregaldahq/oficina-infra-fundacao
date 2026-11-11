# Every secret value is generated here and never leaves Secrets Manager in
# plaintext. Nothing is typed by a human, nothing is committed.

resource "random_password" "db" {
  length  = 32
  special = true
  # RDS master passwords reject / @ " and spaces.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # base64url-safe alphabet keeps HS256 signing portable
}

resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "random_password" "webhook_token" {
  length  = 32
  special = false
}

# Fase 4: token de servico para as rotas /internal/* do servico de OS, que nao
# passam pelo API Gateway (docs/fase-4/CONTRATOS.md, secoes 3 e 4).
resource "random_password" "internal_token" {
  length  = 32
  special = false
}

# --- oficina/<env>/db -------------------------------------------------------
resource "aws_secretsmanager_secret" "db" {
  name                    = "oficina/${var.environment}/db"
  description             = "MySQL credentials for the oficina-mecanica API and migration job."
  recovery_window_in_days = var.secret_recovery_window_days

  tags = { Name = "oficina/${var.environment}/db" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = 3306
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

# --- oficina/<env>/auth -----------------------------------------------------
resource "aws_secretsmanager_secret" "auth" {
  name                    = "oficina/${var.environment}/auth"
  description             = "JWT signing secret, admin credentials and webhook token."
  recovery_window_in_days = var.secret_recovery_window_days

  tags = { Name = "oficina/${var.environment}/auth" }
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id = aws_secretsmanager_secret.auth.id

  secret_string = jsonencode({
    JWT_SECRET     = random_password.jwt_secret.result
    JWT_EXPIRATION = var.jwt_expiration_seconds
    ADMIN_USERNAME = var.admin_username
    ADMIN_PASSWORD = random_password.admin.result
    WEBHOOK_TOKEN  = random_password.webhook_token.result
    INTERNAL_TOKEN = random_password.internal_token.result
  })
}
