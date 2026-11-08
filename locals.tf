locals {
  name_prefix = "oficina-${var.environment}"

  common_tags = {
    Project     = "oficina-mecanica"
    Environment = var.environment
    ManagedBy   = "terraform"
    Repo        = "oficina-infra-database" # nome antigo de oficina-infra-fundacao; mantido para o rename nao gerar diff de tags
  }

  # Duas AZs distintas sao obrigatorias para o DB subnet group do RDS.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs  = ["10.20.0.0/20", "10.20.16.0/20"]
  private_subnet_cidrs = ["10.20.32.0/20", "10.20.48.0/20"]

  is_prod = var.environment == "prod"
}
