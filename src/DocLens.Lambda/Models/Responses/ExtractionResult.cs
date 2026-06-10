namespace DocLens.Lambda.Models.Responses;

public record ExtractionResult
{
    public required string DocumentId { get; init; }
    public required string TenantId { get; init; }
    public required DocumentType DocumentType { get; init; }
    public required Dictionary<string, string> Fields { get; init; }
    public required DateTimeOffset ProcessedAt { get; init; }
}
