using Amazon.Textract;
using Amazon.Textract.Model;

namespace DocLens.Lambda.Services.Ocr;

public class TextractOcrService : IOcrService
{
    private readonly IAmazonTextract _textract;
    private readonly ILogger<TextractOcrService> _logger;
    private readonly string _documentBucket;

    public TextractOcrService(IAmazonTextract textract, IConfiguration configuration, ILogger<TextractOcrService> logger)
    {
        _textract = textract;
        _logger = logger;
        _documentBucket = configuration["DOCUMENT_BUCKET"]
            ?? throw new InvalidOperationException("DOCUMENT_BUCKET is not set.");
    }

    public async Task<string> ExtractTextAsync(string s3Key, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting OCR for {S3Key}", s3Key);

        // TODO: implement async Textract job flow for multi-page documents
        // StartDocumentTextDetection -> poll GetDocumentTextDetection
        // Current stub uses synchronous detection (single-page only)
        var response = await _textract.DetectDocumentTextAsync(new DetectDocumentTextRequest
        {
            Document = new Document
            {
                S3Object = new S3Object { Bucket = _documentBucket, Name = s3Key }
            }
        }, cancellationToken);

        var text = string.Join(" ", response.Blocks
            .Where(b => b.BlockType == BlockType.LINE)
            .Select(b => b.Text));

        _logger.LogInformation("OCR completed for {S3Key}, extracted {CharCount} chars", s3Key, text.Length);

        return text;
    }
}
