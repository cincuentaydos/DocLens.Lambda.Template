using Amazon.Lambda.AspNetCoreServer.Hosting;
using DocLens.Lambda.Context;
using DocLens.Lambda.Endpoints;
using DocLens.Lambda.Extensions;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAWSLambdaHosting(LambdaEventSource.HttpApi);
builder.Services.AddDocLensServices(builder.Configuration);

var app = builder.Build();

app.UseMiddleware<TenantMiddleware>();

app.MapDocumentEndpoints();

app.Run();
