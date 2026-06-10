namespace DocLens.Lambda.Context;

public class TenantContext : ITenantContext
{
    public string TenantId { get; set; } = string.Empty;
}
