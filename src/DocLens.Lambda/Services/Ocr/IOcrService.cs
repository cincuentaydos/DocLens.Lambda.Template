namespace DocLens.Lambda.Services.Ocr;

public interface IOcrService
{
    Task<string> ExtractTextAsync(string s3Key, CancellationToken cancellationToken = default);
}
