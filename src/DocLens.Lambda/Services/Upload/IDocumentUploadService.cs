using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Models.Responses;

namespace DocLens.Lambda.Services.Upload;

public interface IDocumentUploadService
{
    Task<PrepareDocumentUploadResult> PrepareUploadAsync(
        PrepareDocumentUploadRequest request,
        CancellationToken cancellationToken = default);
}
