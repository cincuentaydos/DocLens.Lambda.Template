using Amazon.Textract;
using Amazon.BedrockRuntime;
using DocLens.Lambda.Context;
using DocLens.Lambda.Services.Extraction;
using DocLens.Lambda.Services.Ocr;
using DocLens.Lambda.Services.Semantic;

namespace DocLens.Lambda.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddDocLensServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddDefaultAWSOptions(configuration.GetAWSOptions());

        services.AddAWSService<IAmazonTextract>();
        services.AddAWSService<IAmazonBedrockRuntime>();

        services.AddScoped<TenantContext>();
        services.AddScoped<ITenantContext>(sp => sp.GetRequiredService<TenantContext>());

        services.AddScoped<IOcrService, TextractOcrService>();
        services.AddScoped<ISemanticAnalysisService, BedrockSemanticAnalysisService>();
        services.AddScoped<IDocumentExtractionService, DocumentExtractionService>();

        return services;
    }
}
