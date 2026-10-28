using System.Text.Json;
namespace Gala;

public sealed class BlindSession
{
    public string DirectoryPath
    {
        get;
    }
    readonly List<string> pending = [];
    readonly Dictionary<string, string> locations = [];
    readonly Dictionary<string, (string From, string To, double Time)> previous = [];
    ulong lastSequence;
    bool seedRecorded;
    static readonly HashSet<string> Actions = ["pinch", "slipper", "poison", "vacuum", "cleaner", "visit", "food",
        "chemical", "clean", "threat", "friendly", "pet", "feed", "name", "bond", "gold", "patrol", "leave",
        "recall", "safe", "coexist", "adopt", "share", "stash", "return", "done", "delete", "focus", "cancel",
        "pause", "resume", "release", "select", "rate"];
    public BlindSession(string root)
    {
        DirectoryPath = Path.Combine(root, "BlindPlaytests", Guid.NewGuid().ToString());
    }
    string Location(string raw)
    {
        if (raw.Length == 0)
            return "";
        if (!locations.TryGetValue(raw, out var alias))
            locations[raw] = alias = $"h{locations.Count+1}";
        return alias;
    }
    static double Timestamp => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
    public void Action(string kind, string entity = "", string location = "", double time = 0)
    {
        if (!Actions.Contains(kind))
            return;
        pending.Add(JsonSerializer.Serialize(new
        {
            timestamp = Timestamp,
            worldTime = time,
            playerAction = kind,
            entity = Guid.TryParse(entity, out var id) ? id.ToString() : "",
            location = Location(location)
        }));
    }
    public void Observe(World w)
    {
        if (!seedRecorded)
        {
            pending.Add(JsonSerializer.Serialize(new
            {
                timestamp = Timestamp,
                worldSeed = w.seed,
                version = "1.7.1"
            }));
            seedRecorded = true;
            lastSequence = 0;
        }
        foreach (var e in w.recentEvents.Where(e => (e.sequence ?? 0) > lastSequence))
        {
            string id = Guid.TryParse(e.entity, out var guid) ? guid.ToString() : new[] { "nest", "habitat",
                "mouse", "catPaw" }.Contains(e.entity) ? e.entity : "";
            var row = new Dictionary<string,
                object>{{"timestamp",Timestamp},{"worldTime",e.timestamp},{"sequence",e.sequence??0},{"worldEvent",
                    e.trigger},{"rule",e.rule},{"entity",id},{"location",Location(e.location)}
};
            if (e.trigger == "migration")
            {
                row["from"] = Location(e.previous);
                row["to"] = Location(e.@new);
                row["reversal"] = previous.TryGetValue(id, out var old) && old.From == e.@new && old.To ==
                    e.previous && e.timestamp - old.Time <= 120;
                previous[id] = (e.previous, e.@new, e.timestamp);
            }
            if (new[] { "adult", "baby", "gold", "egg", "hatched", "corpse", "removed", "nest",
                "clear" }.Contains(e.@new))
                row["stage"] = e.@new;
            pending.Add(JsonSerializer.Serialize(row));
            lastSequence = e.sequence ?? lastSequence;
        }
    }
    public void Flush()
    {
        if (pending.Count == 0)
            return;
        Directory.CreateDirectory(DirectoryPath);
        File.AppendAllLines(Path.Combine(DirectoryPath, "observations.jsonl"), pending);
        pending.Clear();
    }
}
