using DocLens.Lambda.Models.Requests;
using DocLens.Lambda.Services.Extraction;

namespace DocLens.Lambda.Endpoints;

public static class DocumentEndpoints
{
    public static IEndpointRouteBuilder MapDocumentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/documents")
            .WithTags("Documents");

        group.MapPost("/process", ProcessDocument)
            .WithName("ProcessDocument")
            .WithSummary("Extracts structured data from a document stored in S3.");

        return app;
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
