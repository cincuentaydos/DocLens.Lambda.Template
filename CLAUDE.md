# DocLens — Project 52

Multi-tenant intelligent document extraction platform on AWS Serverless.
Companies upload documents (invoices, contracts, reports, CVs) and receive structured data extracted automatically via OCR + semantic AI analysis.

## Language rule

**All code, comments, variable names, file names, commit messages, and documentation must be written in English.** No exceptions.

## Tech stack

| Layer | Technology |
|---|---|
| Compute | AWS Lambda (.NET 10) |
| API entry | Amazon API Gateway (HTTP API v2) |
| Identity | Amazon Cognito (JWT with `custom:tenantId` claim) |
| OCR | Amazon Textract |
| AI analysis | Amazon Bedrock (Claude via `InvokeModel`) |
| Operational DB | Amazon DynamoDB |
| Document storage | Amazon S3 |
| Notifications | Amazon SNS / SQS (to be defined) |
| Observability | Amazon CloudWatch + AWS X-Ray + Powertools |
| IaC | AWS CDK (C#) |

## Repository structure

```
src/
  DocLens.Lambda/          # Core Lambda — document processing API
tests/
  DocLens.Lambda.Tests/    # Unit tests (xUnit + NSubstitute)
DocLens.sln
```

## Architecture decisions

- **Inside-out design:** core extraction logic first, infrastructure wiring second.
- **Multi-tenant logical silo:** `tenantId` from Cognito JWT propagates to all layers (S3 prefix, DynamoDB PK, logs).
- **Synchronous extraction for now:** Textract + Bedrock called inline. Async job queue added when needed.
- **SQS as notifier only:** not a processing trigger. Used for post-extraction notifications (email etc.).
- **Primary region:** `eu-west-1` with failover considerations for `eu-west-2`.

## Coding conventions

- Records for immutable DTOs (`ProcessDocumentRequest`, `ExtractionResult`).
- Interface + implementation pairs for all services (`IOcrService` / `TextractOcrService`).
- Services registered as `Scoped`; AWS SDK clients as `Singleton` (via `AddAWSService<T>`).
- `TenantContext` resolved per-request from `TenantMiddleware` before any service runs.
- Structured logging with `ILogger<T>` — always include `TenantId`, `DocumentId`, and operation context.

## Running locally

```bash
# Build
dotnet build

# Test
dotnet test

# Run locally (without Lambda runtime)
dotnet run --project src/DocLens.Lambda
```

## Deployment

Infrastructure is defined via AWS CDK (C#) — not yet in this repo. Manual Lambda deployment for now:

```bash
dotnet lambda deploy-function --project-location src/DocLens.Lambda
```

Requires `dotnet-lambda` CLI tool: `dotnet tool install -g Amazon.Lambda.Tools`
