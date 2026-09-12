namespace DocLens.Lambda.Context;

public class TenantMiddleware
{
    // Cognito adds custom attributes as "custom:<name>" in JWT claims
    private const string TenantIdClaim = "custom:tenantId";

    private readonly RequestDelegate _next;

    public TenantMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context, TenantContext tenantContext)
    {
        // /swagger is the one route API Gateway lets through without a JWT
        // (see modules/processing/api_gateway.tf) — there's no Cognito
        // claim to resolve here, so skip tenant resolution instead of
        // rejecting the request.
        if (context.Request.Path.StartsWithSegments("/swagger"))
        {
            await _next(context);
            return;
        }

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
