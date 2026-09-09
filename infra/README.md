# Infrastructure

All DocLens infrastructure is managed with **Terraform** (see [ADR-002](../../DocLens.Docs/docs/adrs/002-iac-strategy.md) — the AWS CDK scaffold that used to live here has been removed). Two environments: `sbx` and `prod`.

## Layout

```
terraform/
  bootstrap/        # one-time, local state — creates the S3 bucket + DynamoDB table used as the remote backend
  main.tf            # root module — wires everything together
  variables.tf
  outputs.tf
  envs/
    sbx.tfvars
    prod.tfvars
  modules/
    network/         # minimal VPC + 2 private subnets — exists only for Aurora's DB subnet group
    auth/            # Cognito User Pool (tenantId / tipoUsuario / clienteId — see docs/tenant-onboarding.md)
    data/            # Aurora PostgreSQL Serverless v2 + Data API (ADR-008)
    documents/       # S3 document bucket + GuardDuty Malware Protection (ADR-004)
    processing/      # SQS+DLQ, GuardDuty→EventBridge trigger (ADR-011), API Lambda + HTTP API, Processor Lambda, OCR async result Lambda
    knowledge_base/  # Bedrock Knowledge Base on Aurora+pgvector (ADR-001/008) — best-effort, see the module's header comment
    edge/            # Route 53 + ACM + CloudFront + WAF + frontend S3 bucket (ADR-009)
```

## One-time setup

1. **Configure AWS credentials** (`aws configure`, SSO, or env vars) for the account you're deploying into.
2. **Buy a domain** (any cheap TLD works) — this is a manual, billable step outside Terraform. You don't need it to deploy the core stack, only for `modules/edge`.
3. **Bootstrap the state backend** (once per account):
   ```bash
   cd infra/terraform/bootstrap
   terraform init
   terraform apply
   terraform output   # note state_bucket and lock_table
   ```
4. **Fill in `envs/sbx.tfvars` / `envs/prod.tfvars`** with your `domain_name`.
5. **Init the root module** against the bucket from step 3:
   ```bash
   cd infra/terraform
   terraform init \
     -backend-config="bucket=<state_bucket from step 3>" \
     -backend-config="key=infra/sbx/terraform.tfstate" \
     -backend-config="region=eu-west-1" \
     -backend-config="dynamodb_table=doclens-terraform-locks" \
     -backend-config="encrypt=true"
   ```
   Use `key=infra/prod/terraform.tfstate` for the prod environment instead — each environment gets its own state file in the same bucket.
6. **Build the Lambda ZIP** the `lambda_zip_path` variable points at:
   ```bash
   dotnet publish ../../src/DocLens.Lambda -c Release -o /tmp/lambda-out
   zip -j /tmp/lambda-out/doclens-lambda.zip /tmp/lambda-out/*
   ```
7. **Plan, then apply**:
   ```bash
   terraform plan  -var-file=envs/sbx.tfvars
   terraform apply -var-file=envs/sbx.tfvars
   ```
8. **Run the one-time Aurora migration** — `CREATE EXTENSION IF NOT EXISTS vector;` and the `kb` schema (ADR-008) — via the RDS Data API using the cluster ARN and secret ARN from `terraform output`. Not a Terraform resource; do this once per environment before the Knowledge Base module can index anything.
9. **Point your registrar at `terraform output name_servers`** if `create_hosted_zone=true` (the default) and you didn't register the domain directly through Route 53.

## Why the RDS Data API instead of Lambda-in-VPC

Aurora Serverless v2 still requires a VPC (an RDS constraint), but with `enable_http_endpoint = true` both the API Lambda and Bedrock Knowledge Bases reach it over the AWS API plane instead of a direct network connection — no NAT gateway, no VPC-attached Lambda cold-start penalty. See ADR-008 and `modules/network`'s header comment.

## Known rough edges

- `modules/knowledge_base` uses `aws_bedrockagent_knowledge_base`/`aws_bedrockagent_data_source` with an RDS-backed storage configuration — a newer resource shape that may lag in the pinned `hashicorp/aws ~> 5.0` provider (see ADR-002's provider-lag note). If `terraform plan` fails on this module, comment its instantiation out of `main.tf`; nothing else depends on its outputs.
- `modules/documents`' GuardDuty Malware Protection plan and `modules/processing`'s EventBridge scan-result rule (`aws_guardduty_malware_protection_plan`, and the `GuardDuty Malware Protection Object Scan Result` event pattern) are best-effort reconstructions — verify the exact resource schema / event field names against the current AWS docs before treating them as final.
- The "not clean" GuardDuty path (`THREATS_FOUND`/`UNSCANNABLE` → write `REJECTED`) is an open question in ADR-004/ADR-011 and is intentionally not wired yet.
