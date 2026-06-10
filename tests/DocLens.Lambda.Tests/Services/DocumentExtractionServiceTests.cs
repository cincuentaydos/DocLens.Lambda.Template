using DocLens.Lambda.Context;
using DocLens.Lambda.Models;
using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Services.Extraction;
using DocLens.Lambda.Services.Ocr;
using DocLens.Lambda.Services.Semantic;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;

namespace DocLens.Lambda.Tests.Services;

public class DocumentExtractionServiceTests
{
    private readonly IOcrService _ocrService = Substitute.For<IOcrService>();
    private readonly ISemanticAnalysisService _semanticService = Substitute.For<ISemanticAnalysisService>();
    private readonly ITenantContext _tenantContext = Substitute.For<ITenantContext>();

    private DocumentExtractionService CreateSut() => new(
        _ocrService,
        _semanticService,
        _tenantContext,
        NullLogger<DocumentExtractionService>.Instance);

    [Fact]
    public async Task ExtractAsync_ReturnsResult_WithTenantAndDocumentInfo()
    {
        var tenantId = "tenant-abc";
        var documentId = "doc-123";
        var s3Key = "tenant-abc/2026/01/doc-123.pdf";

        _tenantContext.TenantId.Returns(tenantId);
        _ocrService.ExtractTextAsync(s3Key).Returns("Invoice total: $500");
        _semanticService.AnalyzeAsync(Arg.Any<string>(), DocumentType.Invoice)
            .Returns(new Dictionary<string, string> { ["total_amount"] = "$500" });

        var request = new ProcessDocumentRequest(documentId, s3Key, DocumentType.Invoice);
        var result = await CreateSut().ExtractAsync(request);

        Assert.Equal(documentId, result.DocumentId);
        Assert.Equal(tenantId, result.TenantId);
        Assert.Equal("$500", result.Fields["total_amount"]);
    }
}
