namespace DocLens.Lambda.Models.Requests;

public record ProcessDocumentRequest(
    string DocumentId,
    string S3Key,
    DocumentType DocumentType
);
