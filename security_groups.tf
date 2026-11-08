# ---------------------------------------------------------------------------
# The "badge" pattern.
#
# `db-client` is an EMPTY security group. It grants nothing by itself. Whoever
# attaches it (EKS nodes, Lambda ENIs) is allowed into the RDS instance on 3306,
# because the `db` security group references it as an ingress source.
#
# Why not just reference the EKS node SG directly? Because the node SG is owned
# by `oficina-infra-cluster`, which in turn reads the VPC from this stack. Pointing
# at each other would create a circular dependency between two repositories.
# The badge SG is created here, published to SSM, and merely *consumed*
# downstream -- the dependency stays one-way: database -> k8s -> lambda -> app.
# ---------------------------------------------------------------------------
resource "aws_security_group" "db_client" {
  name        = "${local.name_prefix}-db-client"
  description = "Badge SG. Attach it to anything that must reach the RDS instance."
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-db-client" }

  lifecycle {
    create_before_destroy = true
  }
}

# Egress is required so a client can actually open the TCP connection.
resource "aws_vpc_security_group_egress_rule" "db_client_to_db" {
  security_group_id            = aws_security_group.db_client.id
  description                  = "MySQL to the RDS security group"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id

  tags = { Name = "${local.name_prefix}-db-client-egress-3306" }
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db"
  description = "RDS MySQL. Ingress on 3306 only from the db-client badge SG."
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-db" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_client" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from anything carrying the db-client badge"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db_client.id

  tags = { Name = "${local.name_prefix}-db-ingress-3306" }
}
