using System.Text;
using System.Text.Json;
using Amazon.BedrockRuntime;
using Amazon.BedrockRuntime.Model;
using DocLens.Lambda.Models;

namespace DocLens.Lambda.Services.Semantic;

public class BedrockSemanticAnalysisService : ISemanticAnalysisService
{
    // Claude 3 Haiku — fast and cost-efficient for structured extraction
    private const string ModelId = "anthropic.claude-3-haiku-20240307-v1:0";

    private readonly IAmazonBedrockRuntime _bedrock;
    private readonly ILogger<BedrockSemanticAnalysisService> _logger;

    public BedrockSemanticAnalysisService(IAmazonBedrockRuntime bedrock, ILogger<BedrockSemanticAnalysisService> logger)
    {
        _bedrock = bedrock;
        _logger = logger;
    }

    public async Task<Dictionary<string, string>> AnalyzeAsync(
        string rawText,
        DocumentType documentType,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting semantic analysis for document type {DocumentType}", documentType);

        var prompt = BuildPrompt(rawText, documentType);

        var requestBody = JsonSerializer.Serialize(new
        {
            anthropic_version = "bedrock-2023-05-31",
            max_tokens = 1024,
            messages = new[]
            {
                new { role = "user", content = prompt }
            }
        });

        var response = await _bedrock.InvokeModelAsync(new InvokeModelRequest
        {
            ModelId = ModelId,
            ContentType = "application/json",
            Accept = "application/json",
            Body = new MemoryStream(Encoding.UTF8.GetBytes(requestBody))
        }, cancellationToken);

        return ParseResponse(response.Body);
    }

    private static string BuildPrompt(string rawText, DocumentType documentType)
    {
        var fields = documentType switch
        {
            DocumentType.Invoice => "issuer, recipient, invoice_number, issue_date, due_date, total_amount, currency, line_items_summary",
            DocumentType.Contract => "parties, effective_date, expiry_date, governing_law, key_obligations_summary",
            DocumentType.Report => "title, author, date, summary, key_findings",
            DocumentType.Cv => "full_name, email, phone, current_role, skills, education_summary, experience_summary",
            _ => "key_fields"
        };

        return $"""
            Extract the following fields from this {documentType} document: {fields}.
            Return a JSON object where each key is a field name and each value is the extracted text.
            If a field is not found, use an empty string as its value.
            Return only the JSON object, no additional text.

            Document text:
            {rawText}
            """;
    }

    private static Dictionary<string, string> ParseResponse(Stream responseBody)
    {
        using var doc = JsonDocument.Parse(responseBody);
        var content = doc.RootElement
            .GetProperty("content")[0]
            .GetProperty("text")
            .GetString() ?? "{}";

        return JsonSerializer.Deserialize<Dictionary<string, string>>(content)
            ?? new Dictionary<string, string>();
    }
}
