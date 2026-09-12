namespace DocLens.Lambda.Models;

// Source of truth for ADR-005's allow-list — modules/processing keeps this
// in sync manually today; ADR-003's format router should consult this same
// map once it exists.
public static class SupportedDocumentFormats
{
    private static readonly Dictionary<string, string> ContentTypeToExtension = new()
    {
        ["application/pdf"] = "pdf",
        ["text/markdown"] = "md",
        ["text/plain"] = "txt",
        ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = "docx",
        ["application/vnd.openxmlformats-officedocument.presentationml.presentation"] = "pptx",
        ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = "xlsx",
        ["image/png"] = "png",
        ["image/jpeg"] = "jpg",
        ["image/tiff"] = "tiff",
    };

    public static bool TryGetExtension(string contentType, out string extension)
    {
        return ContentTypeToExtension.TryGetValue(contentType, out extension!);
    }
}
