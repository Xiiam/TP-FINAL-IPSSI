# Architecture — Kolab Nextcloud sur AWS

## Schéma général

```mermaid
flowchart TB
    Internet -->|HTTPS 443| ALB
    ALB -->|HTTP 80| ASG

    subgraph VPC["VPC 10.30.0.0/16 — eu-west-3"]
        subgraph pub["Subnets publics (2 AZ)"]
            ALB[ALB]
            NAT[NAT Gateway]
        end
        subgraph app["Subnets privés app (2 AZ)"]
            ASG[ASG — EC2 Nextcloud]
        end
        subgraph db["Subnets privés db (2 AZ)"]
            RDS[(RDS PostgreSQL Multi-AZ)]
        end
    end

    ASG -->|5432| RDS
    ASG -->|VPC Endpoint| S3[(S3 Primary Storage)]
    ASG -->|VPC Endpoint| SM[Secrets Manager]
    ASG -->|VPC Endpoint| KMS[KMS CMK]
```

## Décisions d'architecture

- **Single NAT Gateway** : en environnement `dev`, un seul NAT Gateway suffit pour réduire les coûts (~32$/mois par NAT). En production, un NAT par AZ serait nécessaire pour la haute disponibilité.
- **ASG min/max = 1** : le TP vise la démonstration fonctionnelle. L'ASG est présent pour préparer le passage en production — il suffit d'augmenter `min_size` et `max_size`.
- **Certificat self-signed** : généré par le provider `tls` pour activer HTTPS sans domaine enregistré. En production, on utiliserait ACM avec un domaine Route53.
- **VPC Endpoints** : S3, Secrets Manager et KMS sont accessibles via endpoints privés — le trafic ne sort jamais sur Internet, ce qui renforce la sécurité RGPD.
- **RDS Multi-AZ** : haute disponibilité et zéro perte de données en cas de défaillance d'une AZ.
