using Gala;
using System.Text.Json;
using System.Diagnostics;
var options = new JsonSerializerOptions { WriteIndented = true, PropertyNameCaseInsensitive = true };
var input = JsonSerializer.Deserialize<Scenario>(File.ReadAllText(args[0]), options)!;
var w = input.initial ?? new World(input.seed);
if (input.initial == null)
{
    w.migrationMode = input.migrationMode;
    w.habitats = input.habitats;
    foreach (var c in input.creatures)
    {
        string id = w.Add(c.stage, c.location, c.id.Length == 0 ? null : c.id, false);
        var added = w.creatures.Find(x => x.id == id)!;
        if (c.boldness.HasValue)
            added.boldness = c.boldness.Value;
        if (c.cooldown.HasValue)
            added.cooldown = c.cooldown.Value;
        added.protection = c.protection;
        added.age = c.age;
    }
}
var events = new List<WorldEvent>();
var samples = new List<object>();
var capacityEvidence = new CapacityEvidence();
capacityEvidence.Observe(w, 0);
int removalInterval = input.removeCorpsesEvery ?? 0;
int nextCorpseRemoval = removalInterval > 0 ? removalInterval : int.MaxValue;
var timer = Stopwatch.StartNew();
for (int t = 0; t < input.duration; t += 2)
{
    if (removalInterval > 0 && t >= nextCorpseRemoval)
    {
        foreach (var c in w.creatures.Where(c => c.stage == "corpse"))
            w.Send(new("remove", c.location, c.id));
        nextCorpseRemoval += ((t - nextCorpseRemoval) / removalInterval + 1) * removalInterval;
    }
    foreach (var a in input.actions.Where(a => t >= a.at && (a.every > 0 ? (t - a.at) % a.every == 0 : t == a.at)))
        w.Send(new(a.kind, a.location, a.entity, a.amount));
    w.recentEvents.Clear();
    w.Step(input.rate);
    capacityEvidence.Observe(w, 2);
    events.AddRange(w.recentEvents);
    if (t % 60 == 0)
        samples.Add(new
        {
            eggAge = w.creatures.Where(c => c.stage == "egg").Select(c => c.age).DefaultIfEmpty(0).Max(),
            juveniles = w.creatures.Count(c => c.stage == "baby"),
            time = w.time,
            population = w.creatures.Count(c => c.roach),
            eggs = w.creatures.Count(c => c.stage == "egg"),
            nests = w.habitats.Count(h => h.nest),
            w.deaths,
            w.migrations
        });
}
timer.Stop();
var result = new
{
    world = w,
    eventLog = events,
    samples,
    metrics = new
    {
        population =
    w.creatures.Count(c => c.roach),
        eggs = w.creatures.Count(c => c.stage == "egg"),
        nests =
    w.habitats.Count(h => h.nest),
        w.deaths,
        w.migrations,
        w.births,
        elapsedMs = timer.Elapsed.TotalMilliseconds
    },
    unexpectedInteractions = events.Where(e => e.trigger is "migration" or "formation" or
    "passing resident").ToArray(),
    capacityEvidence
};
File.WriteAllText(args[1], JsonSerializer.Serialize(result, options));
Console.WriteLine($"{input.name}: population={w.creatures.Count(c=>c.roach)} eggs={w.creatures.Count(c=>c.stage=="egg")} nests={w.habitats.Count(h=>h.nest)} deaths={w.deaths} migrations={w.migrations} {timer.Elapsed.TotalMilliseconds:F1}ms");
public class Scenario
{
    public string migrationMode { get; set; } = "treatment";
    public string name { get; set; } = "";
    public ulong seed { get; set; } = 42;
    public int duration { get; set; } = 1800;
    public double rate { get; set; } = 1;
    public int? removeCorpsesEvery { get; set; }
    public World? initial
    {
        get; set;
    }
    public List<WorldHabitat> habitats { get; set; } = [new(), new() { id = "quiet-edge" }];
    public List<InitialCreature> creatures { get; set; } = [];
    public List<InputAction> actions { get; set; } = [];
}
public class InitialCreature
{
    public string id { get; set; } = "";
    public string stage { get; set; } = "adult";
    public string location { get; set; } = "edge";
    public double? boldness
    {
        get; set;
    }
    public double? cooldown
    {
        get; set;
    }
    public double age
    {
        get; set;
    }
    public bool protection
    {
        get; set;
    }
}
public class InputAction
{
    public int at
    {
        get; set;
    }
    public int every
    {
        get; set;
    }
    public string kind { get; set; } = "visit";
    public string location { get; set; } = "edge";
    public string entity { get; set; } = "";
    public double amount { get; set; } = 1;
}
public class CapacityObservation
{
    public double firstTime { get; set; }
    public double lastTime { get; set; }
    // total, living, eggs, mature eggs, corpses, stains, nests
    public int[] counts { get; set; } = [];
}
public class CapacityEvidence
{
    public double firstAt32 { get; set; } = -1;
    public double matureEggSeconds { get; set; }
    public double matureEggWallSeconds { get; set; }
    public List<CapacityObservation> observations { get; set; } = [];

    public void Observe(World world, double dt)
    {
        int mature = world.creatures.Count(c => c.stage == "egg" && c.age >= 180);
        int[] counts = [
            world.creatures.Count,
            world.creatures.Count(c => c.roach),
            world.creatures.Count(c => c.stage == "egg"),
            mature,
            world.creatures.Count(c => c.stage == "corpse"),
            world.creatures.Count(c => c.stage == "stain"),
            world.habitats.Count(h => h.nest)
        ];
        if (firstAt32 < 0 && counts[0] >= 32)
            firstAt32 = world.time;
        matureEggSeconds += mature * dt;
        if (mature > 0)
            matureEggWallSeconds += dt;
        if (observations.Count > 0 && observations[^1].counts.SequenceEqual(counts))
            observations[^1].lastTime = world.time;
        else
            observations.Add(new CapacityObservation
            {
                firstTime = world.time, lastTime = world.time, counts = counts
            });
    }
}
