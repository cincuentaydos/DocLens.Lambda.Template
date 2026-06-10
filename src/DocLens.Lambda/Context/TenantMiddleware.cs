namespace DocLens.Lambda.Context;

public class TenantMiddleware
{
    // Cognito adds custom attributes as "custom:<name>" in JWT claims
    private const string TenantIdClaim = "custom:tenantId";

    private readonly RequestDelegate _next;

    public TenantMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context, TenantContext tenantContext)
    {
        var tenantId = context.User.FindFirst(TenantIdClaim)?.Value;

        if (string.IsNullOrWhiteSpace(tenantId))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "Tenant identity could not be resolved." });
            return;
        }

        tenantContext.TenantId = tenantId;

        await _next(context);
    }
}
