# DocLens — Project 52

Multi-tenant AI platform for legal case management, on AWS Serverless.
A law firm (tenant) centralizes its Procesos (cases), Clientes, and Documentos, and uses AI to classify documents, extract data, summarize, answer contextual questions about a case, and draft first versions of documents/communications. See `DocLens.Docs` (ADR-001…013) for the full architecture.

## Language rule

**All code, comments, variable names, file names, commit messages, and documentation must be written in English.** No exceptions.

## Tech stack

| Layer | Technology |
|---|---|
| Compute | AWS Lambda (.NET 10) — API Lambda + Processor Lambda (ADR-010) |
| API entry | Amazon API Gateway (HTTP API v2), single catch-all route, JWT authorizer |
| Identity | Amazon Cognito (JWT with `custom:tenantId`, `custom:tipoUsuario`, `custom:clienteId` claims) |
| Text extraction | PdfPig (digital PDF) → Amazon Textract fallback; native parse for `.md`/`.docx`/etc. (ADR-003) |
| AI analysis | Amazon Bedrock (Claude via `InvokeModel`); no autonomous agent (ADR-012) |
| RAG | Amazon Bedrock Knowledge Bases, Aurora + pgvector as the vector store (ADR-001/008) |
| Operational DB + vector store | Amazon Aurora PostgreSQL Serverless v2 + pgvector, reached via the RDS Data API (ADR-008) |
| Document storage | Amazon S3 (versioned) |
| Processing trigger | GuardDuty Malware Protection → EventBridge → SQS → Processor Lambda (ADR-011) — no client-called `/process` endpoint |
| Edge | Route 53 + CloudFront + WAF + Shield Standard + ACM (ADR-009) |
| Observability | Amazon CloudWatch + AWS X-Ray + Powertools |
| IaC | Terraform (HCL) only — see `infra/terraform/` (the CDK scaffold has been removed, ADR-002) |

## Repository structure

```
src/
  DocLens.Lambda/          # Core Lambda — document processing API
tests/
  DocLens.Lambda.Tests/    # Unit tests (xUnit + NSubstitute)
infra/
  terraform/               # Terraform — the only IaC (see infra/README.md for module layout)
DocLens.slnx
```

## Architecture decisions

- **Inside-out design:** core extraction logic first, infrastructure wiring second.
- **Multi-tenant logical silo:** `tenantId`/`empresa_id` from Cognito JWT propagates to all layers (S3 prefix, Aurora rows, Bedrock KB metadata filter, logs).
- **Asynchronous, event-driven extraction:** GuardDuty scan completion drives the pipeline via EventBridge → SQS → Processor Lambda — no client-called processing endpoint (ADR-011).
- **No autonomous agent:** AI flow is explicit and backend-orchestrated — authorize → retrieve from Bedrock KB → generate with Claude → return with cited sources (ADR-012).
- **Environments:** `sbx` and `prod` only.
- **Primary region:** `eu-west-1`, single region for V1 — no active multi-region deploy (ADR-013).

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

This repo's own compute (`processing` module: API/Processor/OCR-result Lambdas, API Gateway, SQS) is managed via Terraform (`infra/terraform/`) — see `infra/README.md` for setup and `sbx`/`prod` tfvars. Everything else (Cognito, Aurora, document bucket, Knowledge Base, CloudFront/WAF/DNS, and the one-time Aurora `pgvector` migration) lives in the separate `DocLens.Infra` repo — see its README for the cross-repo wiring between the two.

Manual Lambda deployment (outside Terraform, for quick iteration):

```bash
dotnet lambda deploy-function --project-location src/DocLens.Lambda
```

Requires `dotnet-lambda` CLI tool: `dotnet tool install -g Amazon.Lambda.Tools`
