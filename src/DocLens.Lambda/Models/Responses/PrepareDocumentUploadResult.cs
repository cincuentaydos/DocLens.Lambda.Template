namespace DocLens.Lambda.Models.Responses;

public record PrepareDocumentUploadResult
{
    public required string DocumentId { get; init; }
    public required int VersionNumber { get; init; }
    public required string UploadUrl { get; init; }
    public required DateTimeOffset ExpiresAt { get; init; }
}
