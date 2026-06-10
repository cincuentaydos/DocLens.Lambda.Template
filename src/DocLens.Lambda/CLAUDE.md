# DocLens.Lambda

The core Lambda function. Receives document processing requests via API Gateway (HTTP API v2), runs OCR through Textract, semantic analysis through Bedrock, and returns structured data.

## Entry point

`Program.cs` — Minimal APIs host with Lambda hosting, tenant middleware, and endpoint registration.

## Request flow

```
API Gateway → TenantMiddleware → Endpoint → DocumentExtractionService
                                                ├── TextractOcrService   (raw text)
                                                └── BedrockSemanticAnalysisService  (structured fields)
```

## Directory layout

```
Endpoints/               # Route definitions — one file per domain area
Models/
  Requests/              # Inbound DTOs (records)
  Responses/             # Outbound DTOs (records)
Services/
  Extraction/            # Orchestration: IDocumentExtractionService
  Ocr/                   # Textract wrapper: IOcrService
  Semantic/              # Bedrock wrapper: ISemanticAnalysisService
Context/                 # Tenant resolution (TenantContext, TenantMiddleware)
Extensions/              # DI registration (ServiceCollectionExtensions)
```

## Adding a new endpoint

1. Add the route to the relevant file in `Endpoints/` (or create a new one for a new domain).
2. Register it in `MapDocumentEndpoints` (or add a new `Map*Endpoints` extension and call it from `Program.cs`).
3. Create request/response records in `Models/`.
4. Implement the backing service under `Services/`.

## Multi-tenant rule

Every service that touches data **must** receive `ITenantContext` via constructor injection and include `TenantId` in all storage keys, log statements, and response objects.

S3 key convention: `{tenantId}/{year}/{month}/{documentId}.pdf`
DynamoDB PK convention: `TENANT#{tenantId}`

## Adding a new document type

1. Add the variant to `Models/DocumentType.cs`.
2. Add a matching `case` in `BedrockSemanticAnalysisService.BuildPrompt` with the relevant extraction fields.

## AWS SDK pattern

Services receive SDK clients via constructor injection (`IAmazonTextract`, `IAmazonBedrockRuntime`).
Never instantiate AWS clients directly — always use DI.

## Testing

- Unit tests in `tests/DocLens.Lambda.Tests/`.
- Mock all AWS SDK interfaces with NSubstitute — never make real AWS calls in tests.
- Each service test file mirrors the `Services/` layout.
