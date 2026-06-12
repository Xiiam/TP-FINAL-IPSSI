# =============================================================================
# modules/networking/main.tf
# ROLE 2 (Network Engineer)
# =============================================================================
# OBJECTIF : creer le reseau complet Nextcloud.
#
# Ressources declarees :
#   - aws_vpc                              "main"
#   - aws_internet_gateway                 "main"
#   - aws_subnet                           "public"        (for_each sur local.public_subnets)
#   - aws_subnet                           "private_app"   (for_each sur local.private_app_subnets)
#   - aws_subnet                           "private_db"    (for_each sur local.private_db_subnets)
#   - aws_eip                              "nat"           (domain = "vpc")
#   - aws_nat_gateway                      "main"          (subnet_id = premiere AZ public)
#   - aws_route_table                      "public"        (route 0.0.0.0/0 -> IGW)
#   - aws_route_table                      "private"       (route 0.0.0.0/0 -> NAT)
#   - aws_route_table_association          "public"        (for_each, 2 associations)
#   - aws_route_table_association          "private_app"   (for_each)
#   - aws_route_table_association          "private_db"    (for_each)
#   - aws_security_group                   "vpc_endpoints" (443 from vpc_cidr)
#   - aws_vpc_security_group_ingress_rule  "vpce_https_from_vpc"
#   - aws_vpc_endpoint                     "s3"            (type = Gateway)
#   - aws_vpc_endpoint                     "secretsmanager" (type = Interface, private_dns_enabled = true)
#
# Total : ~20 ressources
# Les locals (name_prefix + 3 maps AZ -> CIDR) sont deja dans locals.tf.
# =============================================================================

# =============================================================================
# Etape 4 : VPC + IGW
# enable_dns_support et enable_dns_hostnames requis pour les VPCE avec DNS prive
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# =============================================================================
# Etape 5 : 6 subnets (3 types x 2 AZ)
# =============================================================================
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app" {
  for_each = local.private_app_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-private-app-${each.key}"
    Tier = "private-app"
  }
}

resource "aws_subnet" "private_db" {
  for_each = local.private_db_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-private-db-${each.key}"
    Tier = "private-db"
  }
}

# =============================================================================
# Etape 6 : EIP + NAT Gateway single AZ (dev — voir ARCHITECTURE.md)
# depends_on requis : evite InvalidAllocationID.NotFound au plan suivant
# =============================================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.azs[0]].id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Etape 7 : Route tables + 6 associations
# Les subnets DB utilisent la RT privee (acces KMS pour snapshots)
# =============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# Etape 8 : VPC Endpoint S3 — gateway, gratuit
# Injecte une route dans la RT privee : trafic S3 ne passe pas par NAT
# =============================================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-west-3.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "${local.name_prefix}-vpce-s3"
  }
}

# =============================================================================
# Etape 9 : SG VPC endpoints + VPC Endpoint Secrets Manager — interface
# private_dns_enabled = true : secretsmanager.eu-west-3.amazonaws.com
# resout vers IP privee de l ENI (transparent pour le SDK AWS)
# =============================================================================
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpce-sg"
  description = "Autorise HTTPS depuis VPC vers les VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-vpce-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https_from_vpc" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "HTTPS 443 depuis le VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-3.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [for s in aws_subnet.private_app : s.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "${local.name_prefix}-vpce-secretsmanager"
  }
}
