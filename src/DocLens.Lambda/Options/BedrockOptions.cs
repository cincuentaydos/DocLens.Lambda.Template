namespace DocLens.Lambda.Options;

public sealed class BedrockOptions
{
    public const string SectionName = "Bedrock";

    public string ModelId { get; init; } = "anthropic.claude-3-haiku-20240307-v1:0";
    public int MaxTokens { get; init; } = 1024;
}
