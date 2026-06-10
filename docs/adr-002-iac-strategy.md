# ADR-002: Infrastructure as Code Strategy — AWS CDK vs Terraform

## Status

Proposed — pending team decision

## Date

2026-06-10

## Context

DocLens requires infrastructure provisioned and maintained across at least three environments (development, staging, production) in AWS. The services involved include Lambda, API Gateway, Cognito, S3, DynamoDB, Textract, Bedrock, SQS, SNS, CloudWatch, and X-Ray — with Bedrock Knowledge Bases likely added as the RAG layer matures.

Two IaC tools are under consideration: **AWS CDK (C#)** and **Terraform**.

The team already operates Terraform in a related project (allerac-one), managing multi-cloud infrastructure across AWS, GCP, and Azure.

---

## Alternatives Considered

### Option A — AWS CDK (C#)

CDK is an AWS-native framework that lets you define infrastructure in a general-purpose programming language. It synthesises to CloudFormation, which AWS then uses to provision resources.

**Strengths:**

- **Same language as the application.** C# is already the language of the Lambda functions. Developers do not need to context-switch to a different language or toolchain.
- **Higher-level constructs.** CDK L2 and L3 constructs encode AWS best practices by default: IAM least-privilege policies, Lambda bundling and asset management, log retention, and encryption — without writing every detail manually.
- **First-class AWS support.** New AWS services and features are typically available in CDK before the Terraform AWS provider catches up. Bedrock Knowledge Bases, for example, had complete CDK support weeks before a stable Terraform resource was available.
- **Native Lambda tooling.** CDK integrates with `dotnet lambda` for packaging and deployment, making the Lambda asset pipeline straightforward.

**Weaknesses:**

- **AWS only.** CDK cannot manage resources outside AWS (Cloudflare DNS, GitHub Actions OIDC, external monitoring, etc.).
- **CloudFormation underneath.** All state is managed by CloudFormation stacks. Drift detection and stack rollback are CloudFormation's responsibility, which can be opaque and slow compared to explicit state management.
- **Team has no existing CDK workflow.** The team would be building CDK expertise from scratch, with no reference implementation to draw from.
- **Harder to inspect deployed state.** Understanding what is currently deployed requires querying CloudFormation, which is less transparent than reading a `.tfstate` file.

---

### Option B — Terraform (proposed)

Terraform is a declarative IaC tool using HCL. It maintains explicit state in a `.tfstate` file and supports multiple cloud providers through a plugin ecosystem.

**Strengths:**

- **Team familiarity.** The team already uses Terraform in allerac-one for AWS, GCP, and Azure. Workflows, module patterns, remote state, and CI/CD integration are already established.
- **Explicit state management.** The `.tfstate` file is the source of truth for what is deployed. `terraform plan` shows a precise diff before any change is applied. Drift detection is built in.
- **Cross-provider resources.** When DocLens needs resources outside AWS — Cloudflare for DNS, GitHub for OIDC trust, external secrets rotation — Terraform handles them in the same workflow as AWS resources.
- **Readable and auditable.** HCL is declarative and easy to review in pull requests. Infrastructure changes are visible as plain text diffs.
- **Mature module ecosystem.** Community modules exist for most AWS patterns, reducing boilerplate for VPCs, IAM, and common service configurations.

**Weaknesses:**

- **Provider lag for new AWS services.** The `hashicorp/aws` provider sometimes trails CDK by weeks or months for new features. Bedrock Knowledge Bases, OpenSearch Serverless vector store integration, and some Lambda advanced configurations have had delayed or incomplete Terraform support. Workarounds using `aws_cloudformation_stack` or `null_resource` with AWS CLI calls are possible but add friction.
- **No higher-level constructs.** Every IAM statement, log group, and encryption key must be written explicitly. There is no equivalent to CDK L2 constructs that encode best practices by default.
- **Different language from application code.** HCL is a separate language; developers familiar only with C# need to learn it.

---

## Comparison Summary

| Dimension | AWS CDK (C#) | Terraform |
|---|---|---|
| Team familiarity | Low (new toolchain) | High (used in allerac-one) |
| Language consistency | High (C# throughout) | Low (HCL separate from C#) |
| AWS new service support | Fast (first-class) | Delayed (provider lag) |
| State management | CloudFormation (opaque) | Explicit `.tfstate` (transparent) |
| Cross-provider resources | No | Yes |
| Higher-level constructs | Yes (L2/L3) | No (explicit only) |
| Lambda packaging integration | Native | Manual or via `null_resource` |
| Existing reference in team | No | Yes (allerac-one) |

---

## Open Questions for the Team

1. **Bedrock Knowledge Bases support:** Is the current Terraform AWS provider support for Knowledge Bases sufficient for the planned RAG layer? If not, is the team comfortable using `aws_cloudformation_stack` as a temporary workaround?

2. **State backend:** If Terraform is chosen, where will the remote state live — S3 + DynamoDB locking (already used in allerac-one) or Terraform Cloud?

3. **Mono-repo or separate infra repo:** Should Terraform live inside this repository under an `infra/` directory, following the allerac-one pattern, or in a dedicated infrastructure repository?

4. **CDK as escape hatch:** If Terraform is chosen and a specific AWS resource lacks provider support, is the team willing to drop down to a `aws_cloudformation_stack` resource for that piece, or would that create unacceptable complexity?

---

## Related Documents

- [`adr-001-rag-strategy.md`](adr-001-rag-strategy.md) — RAG infrastructure strategy, relevant because Bedrock Knowledge Bases provisioning is one of the resources that may be affected by Terraform provider lag.
