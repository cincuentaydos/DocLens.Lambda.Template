using Amazon.CDK.AWS.Cognito;
using Constructs;

namespace DocLens.Infra.Constructs;

public class AuthConstruct : Construct
{
    public IUserPool UserPool { get; }
    public IUserPoolClient UserPoolClient { get; }

    public AuthConstruct(Construct scope, string id) : base(scope, id)
    {
        UserPool = new UserPool(this, "UserPool", new UserPoolProps
        {
            UserPoolName = "doclens-users",
            SelfSignUpEnabled = false,
            SignInAliases = new SignInAliases { Email = true },
            StandardAttributes = new StandardAttributes
            {
                Email = new StandardAttribute { Required = true, Mutable = false }
            },
            // tenantId is propagated from here to all downstream services
            CustomAttributes = new Dictionary<string, ICustomAttribute>
            {
                ["tenantId"] = new StringAttribute(new StringAttributeProps { Mutable = false })
            },
            PasswordPolicy = new PasswordPolicy
            {
                MinLength = 12,
                RequireUppercase = true,
                RequireLowercase = true,
                RequireDigits = true,
                RequireSymbols = true
            },
            AccountRecovery = AccountRecovery.EMAIL_ONLY
        });

        UserPoolClient = ((UserPool)UserPool).AddClient("WebClient", new UserPoolClientOptions
        {
            AuthFlows = new AuthFlow { UserSrp = true },
            PreventUserExistenceErrors = true
        });
    }
}
