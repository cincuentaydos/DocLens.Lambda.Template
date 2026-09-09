# Infrastructure

This backend's own Terraform — the `processing` module (API Lambda,
Processor Lambda, OCR async result Lambda, API Gateway, SQS/DLQ). Everything
else DocLens needs (Cognito, Aurora, the document bucket, the Bedrock
Knowledge Base, CloudFront/WAF/DNS) lives in the
[`DocLens.Infra`](https://github.com/cincuentaydos/DocLens.Infra) repo — see
[ADR-002](../DocLens.Docs/docs/adrs/002-iac-strategy.md) for why processing
stays here instead of moving there with the rest.

Two environments: `sbx` and `prod`, same single AWS account as `DocLens.Infra`.

## Layout

```
terraform/
  main.tf            # root module — wires modules/processing, reads DocLens.Infra's
                      # outputs via terraform_remote_state
  variables.tf
  outputs.tf
  envs/
    sbx.tfvars
    prod.tfvars
  modules/
    processing/      # SQS+DLQ, GuardDuty→EventBridge trigger (ADR-011), API Lambda + HTTP API, Processor Lambda, OCR async result Lambda
```

## Cross-repo wiring

`processing` needs the document bucket, Aurora cluster, and Cognito User
Pool that `DocLens.Infra` creates. Rather than duplicate those resources
here or collapse both repos into one root, `main.tf`'s
`data.terraform_remote_state.infra` reads them straight from
`DocLens.Infra`'s state (same shared S3 bucket, different key). In the
other direction, `DocLens.Infra`'s `edge` module reads this module's
`api_endpoint` output the same way, for its CloudFront origin — see
`DocLens.Infra/README.md` "Cross-repo wiring" for the full picture and the
first-deploy ordering (short version: `DocLens.Infra` goes first, this repo
second, then `DocLens.Infra` applies once more to pick up `api_endpoint`).

## One-time setup

1. **Configure AWS credentials** (`aws configure`, SSO, or env vars) for the
   account you're deploying into.
2. **Bootstrap the state backend**, once per account — this is
   `DocLens.Infra/bootstrap/`, shared across both repos. See that repo's
   README.
3. **Apply `DocLens.Infra`** for this environment first (its outputs are
   what this module reads).
4. **Init this root module** against the same bucket from step 2:
   ```bash
   cd infra/terraform
   terraform init \
     -backend-config="bucket=<state_bucket from DocLens.Infra/bootstrap>" \
     -backend-config="key=lambda-processing/sbx/terraform.tfstate" \
     -backend-config="region=eu-west-1" \
     -backend-config="dynamodb_table=doclens-terraform-locks" \
     -backend-config="encrypt=true"
   ```
   Use `key=lambda-processing/prod/terraform.tfstate` for the prod environment.
5. **Build the Lambda ZIP** the `lambda_zip_path` variable points at:
   ```bash
   dotnet publish ../../src/DocLens.Lambda -c Release -o /tmp/lambda-out
   zip -j /tmp/lambda-out/doclens-lambda.zip /tmp/lambda-out/*
   ```
6. **Plan, then apply**:
   ```bash
   terraform plan  -var-file=envs/sbx.tfvars
   terraform apply -var-file=envs/sbx.tfvars
   ```
7. **Re-apply `DocLens.Infra`** once — its `edge` module can now read this
   module's `api_endpoint`.

## Known rough edges

- `modules/processing`'s EventBridge scan-result rule
  (`GuardDuty Malware Protection Object Scan Result` event pattern) is a
  best-effort reconstruction — verify the exact event field names against
  current AWS docs before treating it as final.
- The "not clean" GuardDuty path (`THREATS_FOUND`/`UNSCANNABLE` → write
  `REJECTED`) is an open question in ADR-004/ADR-011 and is intentionally
  not wired yet.
