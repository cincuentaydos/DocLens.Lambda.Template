#pragma warning disable CS0612 // alpha constructs are marked obsolete but are the current stable path for HTTP API v2
using Amazon.CDK;
using Amazon.CDK.AWS.Apigatewayv2.Alpha;
using Amazon.CDK.AWS.Apigatewayv2.Authorizers.Alpha;
using Amazon.CDK.AWS.Apigatewayv2.Integrations.Alpha;
using Amazon.CDK.AWS.Cognito;
using Amazon.CDK.AWS.DynamoDB;
using Amazon.CDK.AWS.IAM;
using Amazon.CDK.AWS.Lambda;
using Amazon.CDK.AWS.Logs;
using Amazon.CDK.AWS.S3;
using Constructs;
using GwHttpMethod = Amazon.CDK.AWS.Apigatewayv2.Alpha.HttpMethod;

namespace DocLens.Infra.Constructs;

public class DocumentProcessingConstructProps
{
    public required IBucket DocumentBucket { get; init; }
    public required ITable JobsTable { get; init; }
    public required UserPool UserPool { get; init; }
}

public class DocumentProcessingConstruct : Construct
{
    public IFunction ProcessorFunction { get; }
    public HttpApi Api { get; }

    public DocumentProcessingConstruct(Construct scope, string id, DocumentProcessingConstructProps props)
        : base(scope, id)
    {
        var logGroup = new LogGroup(this, "ProcessorLogs", new LogGroupProps
        {
            LogGroupName = "/aws/lambda/doclens-processor",
            Retention = RetentionDays.ONE_MONTH,
            RemovalPolicy = RemovalPolicy.DESTROY
        });

        ProcessorFunction = new Function(this, "ProcessorFunction", new FunctionProps
        {
            FunctionName = "doclens-processor",
            Runtime = Runtime.DOTNET_8,
            Handler = "DocLens.Lambda",
            Code = Code.FromAsset("../src/DocLens.Lambda", new Amazon.CDK.AWS.S3.Assets.AssetOptions
            {
                Bundling = new BundlingOptions
                {
                    Image = Runtime.DOTNET_8.BundlingImage,
                    Command = new[]
                    {
                        "bash", "-c",
                        "dotnet publish -c Release -o /asset-output --no-self-contained"
                    }
                }
            }),
            MemorySize = 512,
            Timeout = Duration.Seconds(30),
            LogGroup = logGroup,
            Environment = new Dictionary<string, string>
            {
                ["DOCUMENT_BUCKET"] = props.DocumentBucket.BucketName,
                ["JOBS_TABLE"] = props.JobsTable.TableName,
                ["AWS_REGION"] = Stack.Of(this).Region
            },
            Tracing = Tracing.ACTIVE
        });

        props.DocumentBucket.GrantRead(ProcessorFunction);
        props.JobsTable.GrantReadWriteData(ProcessorFunction);

        ProcessorFunction.AddToRolePolicy(new PolicyStatement(new PolicyStatementProps
        {
            Effect = Effect.ALLOW,
            Actions = new[]
            {
                "textract:DetectDocumentText",
                "textract:StartDocumentTextDetection",
                "textract:GetDocumentTextDetection"
            },
            Resources = new[] { "*" }
        }));

        ProcessorFunction.AddToRolePolicy(new PolicyStatement(new PolicyStatementProps
        {
            Effect = Effect.ALLOW,
            Actions = new[] { "bedrock:InvokeModel" },
            Resources = new[] { "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku*" }
        }));

        var authorizer = new HttpJwtAuthorizer("CognitoAuthorizer", props.UserPool.UserPoolProviderUrl,
            new HttpJwtAuthorizerProps
            {
                JwtAudience = new[] { "doclens-web-client" }
            });

        Api = new HttpApi(this, "Api", new HttpApiProps
        {
            ApiName = "doclens-api",
            DefaultAuthorizer = authorizer,
            CorsPreflight = new CorsPreflightOptions
            {
                AllowOrigins = new[] { "*" },
                AllowMethods = new[] { CorsHttpMethod.POST, CorsHttpMethod.GET },
                AllowHeaders = new[] { "Authorization", "Content-Type" }
            }
        });

        Api.AddRoutes(new AddRoutesOptions
        {
            Path = "/documents/process",
            Methods = new[] { GwHttpMethod.POST },
            Integration = new HttpLambdaIntegration("ProcessorIntegration", ProcessorFunction)
        });

        new CfnOutput(this, "ApiEndpoint", new CfnOutputProps
        {
            Value = Api.ApiEndpoint,
            Description = "DocLens API endpoint"
        });
    }
}
