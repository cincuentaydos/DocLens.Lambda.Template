namespace DocLens.Lambda.Options;

public sealed class BedrockOptions
{
    public const string SectionName = "Bedrock";

    public string ModelId { get; init; } = "eu.anthropic.claude-haiku-4-5-20251001-v1:0";
    public int MaxTokens { get; init; } = 1024;
}
