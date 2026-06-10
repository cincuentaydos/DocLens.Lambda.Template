# IaC Comparison: AWS CDK (C#) vs Terraform

## Context

Both implementations provision the same DocLens infrastructure:
S3 bucket, DynamoDB table, Cognito User Pool, Lambda function, API Gateway HTTP v2, IAM roles, and CloudWatch log groups.

The CDK version lives in `infra/src/DocLens.Infra/`.
The Terraform version lives in `infra/terraform/`.

This document reflects real observations made while building both, not hypothetical tradeoffs.

---

## Lines of Code

| Layer | CDK (C#) | Terraform (HCL) |
|---|---|---|
| Storage (S3 + DynamoDB) | 39 lines | 85 lines |
| Auth (Cognito) | 55 lines | 68 lines |
| Processing (Lambda + API GW + IAM) | 125 lines | 165 lines |
| Entry point + stack | 35 lines | 55 lines |
| **Total** | **~254 lines** | **~373 lines** |

CDK is ~30% more concise. The gap comes almost entirely from IAM — CDK generates policies automatically via `grantRead`, `grantReadWriteData`, and `AddToRolePolicy`. Terraform requires writing every IAM statement by hand.

---

## Side-by-Side Examples

### S3 bucket with encryption and SSL enforcement

**CDK**
```csharp
DocumentBucket = new Bucket(this, "DocumentBucket", new BucketProps
{
    Encryption = BucketEncryption.S3_MANAGED,
    BlockPublicAccess = BlockPublicAccess.BLOCK_ALL,
    EnforceSSL = true,
    RemovalPolicy = RemovalPolicy.RETAIN
});
```

**Terraform**
```hcl
resource "aws_s3_bucket" "documents" { ... }

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" { ... }

resource "aws_s3_bucket_public_access_block" "documents" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "enforce_ssl" {
  policy = jsonencode({
    Statement = [{ Condition = { Bool = { "aws:SecureTransport" = "false" } } ... }]
  })
}
```

`EnforceSSL = true` in CDK generates the bucket policy automatically. In Terraform, it requires a separate `aws_s3_bucket_policy` resource with a manually written IAM JSON document. This is representative of how the verbosity gap compounds.

---

### IAM permissions for Lambda

**CDK**
```csharp
props.DocumentBucket.GrantRead(ProcessorFunction);
props.JobsTable.GrantReadWriteData(ProcessorFunction);
```

**Terraform**
```hcl
resource "aws_iam_role_policy" "lambda_permissions" {
  policy = jsonencode({
    Statement = [
      { Sid = "S3Read", Action = ["s3:GetObject", "s3:GetObjectVersion"], ... },
      { Sid = "DynamoDB", Action = ["dynamodb:GetItem", "dynamodb:PutItem",
        "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query",
        "dynamodb:Scan"], ... },
      { Sid = "Logs", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], ... },
      { Sid = "XRay", Action = ["xray:PutTraceSegments", ...], ... }
    ]
  })
}
```

CDK infers least-privilege automatically from the L2 construct methods. Terraform requires knowing the exact IAM actions and writing them explicitly — which is more transparent but significantly more verbose, and easier to get wrong.

---

## Real Issue Encountered: .NET 10 Runtime

While building the Terraform version, the following validation error was hit:

```
expected runtime to be one of [..., "dotnet8", ...], got "dotnet10"
```

The `hashicorp/aws` provider 5.x does not yet include `dotnet10` as a valid runtime enum. The fix was to use `provided.al2023` (custom runtime) with a comment explaining the workaround.

The CDK version used `Runtime.DOTNET_8` without issue — and could reference `dotnet10` as a string if needed, because CDK passes the value directly to CloudFormation without enum validation at the framework level.

This is a concrete example of the provider lag described in [ADR-002](adr-002-iac-strategy.md). It required a workaround on day one of writing the Terraform.

---

## State Management

| Aspect | CDK | Terraform |
|---|---|---|
| State backend | CloudFormation (managed by AWS) | `.tfstate` file (S3 + DynamoDB locking for teams) |
| `plan` equivalent | `cdk diff` | `terraform plan` |
| Visibility | Stack events in CloudFormation console | Plain text diff in terminal |
| Drift detection | CloudFormation drift detection (manual trigger) | `terraform plan` always shows drift |

Terraform's `terraform plan` output is arguably easier to read and more actionable than CloudFormation stack events. It shows exactly which resources will be created, modified, or destroyed before any change is applied.

CloudFormation drift detection must be triggered manually and can be slow. `terraform plan` always reflects current state.

---

## Lambda Packaging

| Aspect | CDK | Terraform |
|---|---|---|
| Build + zip | Automatic via `BundlingOptions` | Manual — must build and zip before `terraform apply` |
| Source change detection | CDK tracks asset hash | `filebase64sha256(var.lambda_zip_path)` |
| CI integration | Single `cdk deploy` step | Requires a build step before `terraform apply` |

CDK's bundling integration is a meaningful advantage for Lambda-heavy projects. The `Code.FromAsset` with `BundlingOptions` runs `dotnet publish` inside a Docker container during `cdk deploy`, so the deployment pipeline is a single command.

With Terraform, a build script (`dotnet publish` + `zip`) must run before `terraform apply`. This is manageable but adds a step that must be wired into CI manually.

---

## Summary

| Dimension | CDK (C#) | Terraform |
|---|---|---|
| Lines of code | ~254 | ~373 |
| Language | C# (same as Lambda code) | HCL (separate language) |
| IAM verbosity | Low (auto-generated grants) | High (every action explicit) |
| Lambda bundling | Automatic | Manual build step required |
| .NET 10 runtime support | Yes | No — `provided.al2023` workaround needed |
| State visibility | CloudFormation events | Explicit `terraform plan` diff |
| Drift detection | Manual trigger | Built into `terraform plan` |
| Team familiarity | Low (new for the team) | High (used in allerac-one) |
| Multi-cloud / external resources | No | Yes |

---

## Recommendation

Neither tool is clearly superior for all scenarios. The decision comes down to two questions:

**If team velocity and single-cloud are the priority:** CDK wins. Less boilerplate, automatic IAM grants, integrated Lambda bundling, and C# throughout. No context-switch between languages.

**If operational consistency and state transparency are the priority:** Terraform wins. The team already knows it, `terraform plan` gives a cleaner picture of what changes before it happens, and external resources (Cloudflare, GitHub) can be managed in the same workflow.

The `.NET 10 runtime` issue encountered during this comparison should be weighted accordingly — it is a real friction point, not a hypothetical one.

See [ADR-002](adr-002-iac-strategy.md) for the formal decision record and open questions for the team.
