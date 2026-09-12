namespace DocLens.Lambda.Models.Requests;

// documentId omitted or null => new document, version 1.
// documentId provided => new version of an existing document (ADR-005).
public record PrepareDocumentUploadRequest(
    string ContentType,
    string? DocumentId
);
