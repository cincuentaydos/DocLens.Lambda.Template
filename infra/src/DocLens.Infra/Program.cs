using Amazon.CDK;
using DocLens.Infra.Stacks;

var app = new App();

var env = new Amazon.CDK.Environment
{
    Account = System.Environment.GetEnvironmentVariable("CDK_DEFAULT_ACCOUNT"),
    Region = System.Environment.GetEnvironmentVariable("CDK_DEFAULT_REGION") ?? "eu-west-1"
};

new DocLensStack(app, "DocLens-Dev", new StackProps
{
    Env = env,
    Tags = new Dictionary<string, string>
    {
        ["Project"] = "DocLens",
        ["Environment"] = "dev"
    }
});

app.Synth();
