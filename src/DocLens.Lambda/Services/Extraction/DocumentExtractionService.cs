using DocLens.Lambda.Context;
using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Models.Responses;
using DocLens.Lambda.Services.Ocr;
using DocLens.Lambda.Services.Semantic;

namespace DocLens.Lambda.Services.Extraction;

public class DocumentExtractionService : IDocumentExtractionService
{
    private readonly IOcrService _ocrService;
    private readonly ISemanticAnalysisService _semanticAnalysisService;
    private readonly ITenantContext _tenantContext;
    private readonly ILogger<DocumentExtractionService> _logger;

    public DocumentExtractionService(
        IOcrService ocrService,
        ISemanticAnalysisService semanticAnalysisService,
        ITenantContext tenantContext,
        ILogger<DocumentExtractionService> logger)
    {
        _ocrService = ocrService;
        _semanticAnalysisService = semanticAnalysisService;
        _tenantContext = tenantContext;
        _logger = logger;
    }

    public async Task<ExtractionResult> ExtractAsync(
        ProcessDocumentRequest request,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Extracting document {DocumentId} of type {DocumentType} for tenant {TenantId}",
            request.DocumentId, request.DocumentType, _tenantContext.TenantId);

        var rawText = await _ocrService.ExtractTextAsync(request.S3Key, cancellationToken);

        var fields = await _semanticAnalysisService.AnalyzeAsync(rawText, request.DocumentType, cancellationToken);

        _logger.LogInformation(
            "Extraction completed for document {DocumentId}, {FieldCount} fields extracted",
            request.DocumentId, fields.Count);

        return new ExtractionResult
        {
            DocumentId = request.DocumentId,
            TenantId = _tenantContext.TenantId,
            DocumentType = request.DocumentType,
            Fields = fields,
            ProcessedAt = DateTimeOffset.UtcNow
        };
    }
}
