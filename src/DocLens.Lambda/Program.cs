using Amazon.Lambda.AspNetCoreServer.Hosting;
using DocLens.Lambda.Context;
using DocLens.Lambda.Endpoints;
using DocLens.Lambda.Extensions;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAWSLambdaHosting(LambdaEventSource.HttpApi);
builder.Services.AddDocLensServices(builder.Configuration);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseMiddleware<TenantMiddleware>();

// Only route API Gateway lets through without a JWT (see
// modules/processing/api_gateway.tf) — everything else still requires a
// Cognito Bearer token, per ADR-005/api-reference.md.
app.UseSwagger();
app.UseSwaggerUI();

app.MapDocumentEndpoints();

app.Run();
