using System.Text.Json;

namespace PocketSpeaker;

internal sealed class HistoryEntry {
    public string Client { get; set; } = "iPhone";
    public DateTimeOffset ConnectedAt { get; set; }
    public string Display => $"{Client}   ·   {ConnectedAt:g}";
}

internal sealed class AppSettings {
    public string Language { get; set; } = "zh";
    public string? DeviceId { get; set; }
    public List<HistoryEntry> History { get; set; } = [];
    private static string DirectoryPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PocketSpeaker");
    private static string FilePath => Path.Combine(DirectoryPath, "settings.json");

    public static AppSettings Load() {
        try { return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath)) ?? new(); }
        catch { return new(); }
    }

    public void Save() {
        Directory.CreateDirectory(DirectoryPath);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}
