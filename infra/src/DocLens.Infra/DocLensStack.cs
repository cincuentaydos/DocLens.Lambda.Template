using Amazon.CDK;
using Constructs;
using DocLens.Infra.Constructs;

namespace DocLens.Infra.Stacks;

public class DocLensStack : Stack
{
    public DocLensStack(Construct scope, string id, IStackProps props = null) : base(scope, id, props)
    {
        var storage = new StorageConstruct(this, "Storage");
        var auth = new AuthConstruct(this, "Auth");
        var processing = new DocumentProcessingConstruct(this, "Processing", new DocumentProcessingConstructProps
        {
            DocumentBucket = storage.DocumentBucket,
            JobsTable = storage.JobsTable,
            UserPool = (Amazon.CDK.AWS.Cognito.UserPool)auth.UserPool
        });
    }
}
