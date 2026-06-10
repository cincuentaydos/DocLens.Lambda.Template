using DocLens.Lambda.Models;

namespace DocLens.Lambda.Services.Semantic;

public interface ISemanticAnalysisService
{
    Task<Dictionary<string, string>> AnalyzeAsync(
        string rawText,
        DocumentType documentType,
        CancellationToken cancellationToken = default);
}
