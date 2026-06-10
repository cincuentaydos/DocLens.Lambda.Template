# ADR-001: RAG Strategy — Bedrock Knowledge Bases vs In-House OpenSearch

## Status

Accepted

## Date

2026-06-10

## Context

DocLens processes documents uploaded by tenants and extracts structured data from them.
Beyond field extraction (invoice number, contract parties, etc.), there is a need to support knowledge retrieval: given a query, find the most relevant content across a tenant's document corpus and synthesise an answer.

This requires a RAG (Retrieval-Augmented Generation) pipeline with three components:

1. **Ingestion:** chunk documents, generate embeddings, store in a vector index.
2. **Retrieval:** given a query embedding, find the most relevant chunks — scoped to a single tenant.
3. **Generation:** pass retrieved chunks to an LLM (Bedrock) to produce a final answer.

The key design question is: who owns the chunking, embedding, and vector store infrastructure?

Two approaches were considered.

---

## Alternatives Considered

### Option A — In-House RAG with Amazon OpenSearch

DocLens owns the full pipeline:

- Text extracted by Textract or PdfPig is explicitly chunked by a `IChunkingStrategy` implementation.
- Chunks are embedded using a Bedrock embedding model (e.g. Titan Embeddings V2 or Cohere Embed v3).
- Embeddings are stored in Amazon OpenSearch (either provisioned or Serverless).
- Retrieval filters by `tenantId` either via a metadata field on a shared index or via a dedicated index per tenant.

**Strengths:**
- Full control over chunking strategy (semantic, page-based, Textract block-based).
- Physical tenant isolation is possible (index per tenant).
- Not bound to Bedrock's ingestion pipeline; any embedding model can be used.
- OpenSearch is open source; vendor lock-in is limited to the managed service layer.

**Weaknesses:**
- Requires managing an OpenSearch cluster or Serverless collection: capacity, scaling, index lifecycle.
- Embedding generation and storage are additional operational responsibilities.
- More code to write and maintain (chunking pipeline, embedding batching, index mapping, retrieval logic).
- Higher complexity from day one, before product-market fit is established.

---

### Option B — Bedrock Knowledge Bases (chosen)

DocLens owns the document processing pipeline (OCR, cleaning, S3 upload). Bedrock Knowledge Bases owns everything after that: chunking, embedding, vector storage, and retrieval.

**How it works:**

1. After Textract or PdfPig processes the document, the clean text or original file is written to S3.
2. A companion metadata file is written alongside it:
   ```
   s3://.../tenant-abc/2026/06/doc-123.pdf
   s3://.../tenant-abc/2026/06/doc-123.pdf.metadata.json
   ```
   The metadata file carries tenant-scoped attributes:
   ```json
   {
     "metadataAttributes": {
       "tenantId": "tenant-abc",
       "documentType": "invoice",
       "documentId": "doc-123"
     }
   }
   ```
3. A `StartIngestionJob` call triggers the Knowledge Base to chunk, embed, and index the document.
4. At query time, the `Retrieve` or `RetrieveAndGenerate` API is called with a metadata filter:
   ```json
   { "filter": { "equals": { "key": "tenantId", "value": "tenant-abc" } } }
   ```
   This ensures a tenant can only retrieve chunks from their own documents.

**Tenant isolation model:** logical silo via metadata filtering on a shared index — consistent with the isolation model used in DynamoDB (`PK: TENANT#{tenantId}`) and S3 (`{tenantId}/{year}/{month}/{documentId}`).

**Chunking strategies available in Knowledge Bases:**

| Strategy | Description | Best for |
|---|---|---|
| Fixed size | Split by character count with overlap | Simple documents |
| Hierarchical | Parent chunks contain child chunks; retrieval returns child with parent context | Long documents needing context |
| Semantic | NLP-based sentence/paragraph boundary detection | Prose-heavy documents (contracts, reports) |
| No chunking | Document passed as a single unit | Pre-chunked input or very short documents |

The semantic strategy is recommended as the default for DocLens document types.

---

## Decision

**Use Amazon Bedrock Knowledge Bases as the RAG infrastructure layer.**

DocLens retains ownership of:
- Document intake, validation, and access control.
- OCR pipeline (Textract or PdfPig — see `ocr-strategy.md`).
- S3 storage layout and metadata authoring.
- Ingestion job triggering (`StartIngestionJob`).
- Retrieval interface abstraction (`IRetrievalService`) that wraps the Knowledge Bases API.

Bedrock Knowledge Bases owns:
- Chunking.
- Embedding model execution.
- Vector store (backed by OpenSearch Serverless).
- Index lifecycle.

---

## Consequences

### What this enables

- **Fast time to value.** No cluster to provision, no embedding pipeline to build. The RAG capability can ship in days rather than weeks.
- **Managed scaling.** Knowledge Bases scales automatically; DocLens does not need to size an OpenSearch cluster.
- **Clean separation of concerns.** DocLens focuses on document quality (OCR, extraction); AWS focuses on retrieval infrastructure.
- **Migration path preserved.** The `IRetrievalService` interface hides the Knowledge Bases implementation. If a future requirement demands physical tenant isolation or custom embeddings, the interface stays stable while the implementation is replaced with in-house OpenSearch.

### What this constrains

- **Chunking is not fully controlled.** The Textract block structure (tables, sections, key-value pairs) cannot be used directly as chunk boundaries. If retrieval quality requires block-level chunking, this becomes a reason to revisit the decision.
- **Tenant isolation is logical, not physical.** A misconfigured filter could expose cross-tenant data. This must be enforced at the `IRetrievalService` layer — the `tenantId` filter must never be optional.
- **Embedding model is limited to Bedrock's catalogue.** Currently: Amazon Titan Embeddings V2, Cohere Embed v3. Custom or self-hosted models are not an option with this approach.
- **AWS lock-in at the RAG layer.** Knowledge Bases is AWS-specific. Migrating to a different cloud or self-hosted vector store requires replacing the ingestion and retrieval layers.

---

## Trigger for Revisiting

This decision should be revisited if any of the following occurs:

- A tenant requires physical data isolation by contractual or regulatory obligation.
- Retrieval quality is demonstrably insufficient with the available chunking strategies and block-level chunking from Textract is needed.
- A non-Bedrock embedding model is required (e.g. a fine-tuned domain-specific model).
- AWS Knowledge Bases pricing becomes a significant cost driver at scale relative to a self-managed OpenSearch alternative.

---

## Related Documents

- [`ocr-strategy.md`](ocr-strategy.md) — PdfPig vs Textract tradeoffs and the hybrid fast path recommendation.
