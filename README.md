# Kolab — Nextcloud sur AWS (TP05)

Kolab est un cabinet d'avocats de 40 collaborateurs qui migre son stockage de fichiers vers AWS pour répondre aux exigences RGPD. Ce projet déploie Nextcloud sur AWS avec Terraform en infrastructure as code.

Voir [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Quick start

```bash
# 1. Prérequis : AWS CLI v2, Terraform >= 1.10
aws sts get-caller-identity  # vérifier le profil

# 2. Bootstrap bucket state (one-shot, un seul membre de l'équipe)
export AWS_PROFILE=formation
USERNAME=groupe03 REGION=eu-west-3 ./bootstrap/create-state-bucket.sh

# 3. Adapter envs/dev/backend.tf avec le bucket créé

# 4. Init + plan + apply
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars avec votre IP publique (curl ifconfig.me)
terraform init
terraform plan
terraform apply
```

---

## Structure

- `bootstrap/` : script one-shot bucket state + KMS CMK
- `global/` : ressources partagées multi-env (OIDC GitHub, bonus)
- `modules/networking` : VPC + subnets + NAT + endpoints (Rôle 2)
- `modules/compute` : ALB + ASG + EC2 Nextcloud (Rôle 3)
- `modules/data` : RDS PG + S3 (Rôle 4)
- `modules/security` : SGs + KMS + IAM + Secrets (Rôle 5)
- `envs/dev` : orchestration de l'environnement de dev (Rôle 1)

---

## Équipe

| Rôle | Nom | Module |
|------|-----|--------|
| Rôle 1 — Platform Lead | Maxime | bootstrap/ + envs/dev/ |
| Rôle 2 — Network Engineer | Maxime | modules/networking/ |
| Rôle 3 — Compute Engineer | Kilian | modules/compute/ |
| Rôle 4 — Data Engineer | Samuel | modules/data/ |
| Rôle 5 — Security Engineer | Mathéo | modules/security/ |

---

## Destroy

```bash
cd envs/dev
terraform destroy
```

**Vérifications post-destroy** : aucun NAT Gateway, aucune RDS, aucune EC2, aucun ALB ne doit rester.
