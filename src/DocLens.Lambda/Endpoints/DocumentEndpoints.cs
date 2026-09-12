using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Services.Extraction;
using DocLens.Lambda.Services.Upload;

namespace DocLens.Lambda.Endpoints;

public static class DocumentEndpoints
{
    public static IEndpointRouteBuilder MapDocumentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/documents")
            .WithTags("Documents");

        group.MapPost("/prepare", PrepareUpload)
            .WithName("PrepareDocumentUpload")
            .WithSummary("Generates a presigned upload URL for a new document version (ADR-005).");

        group.MapPost("/process", ProcessDocument)
            .WithName("ProcessDocument")
            .WithSummary("Extracts structured data from a document stored in S3.");

        return app;
    }

    private static async Task<IResult> PrepareUpload(
        PrepareDocumentUploadRequest request,
        IDocumentUploadService uploadService,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await uploadService.PrepareUploadAsync(request, cancellationToken);
            return Results.Ok(result);
        }
        catch (UnsupportedContentTypeException ex)
        {
            return Results.BadRequest(new { error = ex.Message });
        }
        catch (DocumentNotFoundException ex)
        {
            return Results.NotFound(new { error = ex.Message });
        }
    }

    private static async Task<IResult> ProcessDocument(
        ProcessDocumentRequest request,
        IDocumentExtractionService extractionService,
        CancellationToken cancellationToken)
    {
        var result = await extractionService.ExtractAsync(request, cancellationToken);
        return Results.Ok(result);
    }
}
