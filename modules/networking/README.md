# modules/networking

VPC 10.30.0.0/16 + 6 subnets sur 2 AZ + NAT Gateway single + 2 VPC endpoints.

## Inputs

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| project_name | string | requis | Nom de projet (préfixe les tags Name) |
| environment | string | requis | Nom de l'environnement (dev, staging, prod) |
| vpc_cidr | string | `10.30.0.0/16` | CIDR block du VPC |
| azs | list(string) | `["eu-west-3a", "eu-west-3b"]` | Zones de disponibilité (2 exactement) |

## Outputs

| Nom | Description |
|-----|-------------|
| vpc_id | ID du VPC créé |
| vpc_cidr | CIDR block du VPC |
| public_subnet_ids | Map AZ -> ID des subnets publics |
| private_app_subnet_ids | Map AZ -> ID des subnets privés app |
| private_db_subnet_ids | Map AZ -> ID des subnets privés DB |
| nat_gateway_public_ip | IP publique de la NAT Gateway |
| vpc_endpoints_security_group_id | SG attaché aux VPC endpoints |

## Usage

```hcl
module "networking" {
  source       = "../../modules/networking"
  project_name = "kolab"
  environment  = "dev"
  vpc_cidr     = "10.30.0.0/16"
  azs          = ["eu-west-3a", "eu-west-3b"]
}
```
