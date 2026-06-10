using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Models.Responses;

namespace DocLens.Lambda.Services.Extraction;

public interface IDocumentExtractionService
{
    Task<ExtractionResult> ExtractAsync(
        ProcessDocumentRequest request,
        CancellationToken cancellationToken = default);
}
