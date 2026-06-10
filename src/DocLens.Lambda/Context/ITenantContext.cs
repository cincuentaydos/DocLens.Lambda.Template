namespace DocLens.Lambda.Context;

public interface ITenantContext
{
    string TenantId { get; }
}
