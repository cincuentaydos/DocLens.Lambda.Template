using Amazon.CDK;
using Amazon.CDK.AWS.DynamoDB;
using Amazon.CDK.AWS.S3;
using Constructs;

namespace DocLens.Infra.Constructs;

public class StorageConstruct : Construct
{
    public IBucket DocumentBucket { get; }
    public ITable JobsTable { get; }

    public StorageConstruct(Construct scope, string id) : base(scope, id)
    {
        DocumentBucket = new Bucket(this, "DocumentBucket", new BucketProps
        {
            // s3://{tenantId}/{year}/{month}/{documentId}.pdf
            BucketName = $"doclens-documents-{Stack.Of(this).Account}",
            Encryption = BucketEncryption.S3_MANAGED,
            BlockPublicAccess = BlockPublicAccess.BLOCK_ALL,
            EnforceSSL = true,
            Versioned = false,
            RemovalPolicy = RemovalPolicy.RETAIN
        });

        JobsTable = new Table(this, "JobsTable", new TableProps
        {
            // PK: TENANT#{tenantId}  SK: JOB#{jobId}
            TableName = "doclens-jobs",
            PartitionKey = new Amazon.CDK.AWS.DynamoDB.Attribute { Name = "PK", Type = Amazon.CDK.AWS.DynamoDB.AttributeType.STRING },
            SortKey = new Amazon.CDK.AWS.DynamoDB.Attribute { Name = "SK", Type = Amazon.CDK.AWS.DynamoDB.AttributeType.STRING },
            BillingMode = BillingMode.PAY_PER_REQUEST,
            Encryption = TableEncryption.AWS_MANAGED,
            RemovalPolicy = RemovalPolicy.RETAIN,
            TimeToLiveAttribute = "ExpiresAt"
        });
    }
}
