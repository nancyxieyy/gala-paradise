namespace Gala;
// Same ecological model as Sources/World.swift. No native desktop or wall-clock dependency.
public class WorldHabitat
{
    public string id { get; set; } = "edge";
    public double disturbance
    {
        get; set;
    }
    public double activity
    {
        get; set;
    }
    public double food { get; set; } = .35;
    public double nestability { get; set; } = .8;
    public double chemical
    {
        get; set;
    }
    public double safety
    {
        get; set;
    }
    public double pressure
    {
        get; set;
    }
    public double lastVisited
    {
        get; set;
    }
    public double stable
    {
        get; set;
    }
    public bool nest
    {
        get; set;
    }
    public bool exposed
    {
        get; set;
    }
    public bool discovered
    {
        get; set;
    }
}
public class WorldCreature
{
    public string id { get; set; } = "";
    public string stage { get; set; } = "adult";
    public string home { get; set; } = "edge";
    public string location { get; set; } = "edge";
    public string intent { get; set; } = "idle";
    public string locationMemory { get; set; } = "edge";
    public string emergedFrom { get; set; } = "edge";
    public double lastMigrationTime { get; set; } = -1;
    public string previousLocation { get; set; } = "";
    public string originEgg { get; set; } = "";
    public double age
    {
        get; set;
    }
    public double energy { get; set; } = 1;
    public double hunger { get; set; } = .2;
    public double fear
    {
        get; set;
    }
    public double curiosity { get; set; } = .5;
    public double boldness { get; set; } = .5;
    public double fertility { get; set; } = .6;
    public double trust
    {
        get; set;
    }
    public double threat
    {
        get; set;
    }
    public double friendly
    {
        get; set;
    }
    public double exposure
    {
        get; set;
    }
    public double resistance { get; set; } = .5;
    public double distance { get; set; } = .5;
    public double cooldown
    {
        get; set;
    }
    public double visibleUntil
    {
        get; set;
    }
    [System.Text.Json.Serialization.JsonPropertyName("protected")]
    public bool protection
    {
        get; set;
    }
    public bool playerChemical
    {
        get; set;
    }
    [System.Text.Json.Serialization.JsonIgnore] public bool roach => stage is "adult" or "baby" or "gold";
}
public record WorldEvent(double timestamp, string entity, string location, string trigger, string previous,
    string @new, string rule, ulong? sequence = null);
public record WorldSignal(string kind, string location = "edge", string entity = "", double amount = 1);
public record DirectorParameters(double pressure = 1, double rarity = 1, double tension = 0);
public interface IWorldDirector
{
    DirectorParameters Parameters(World world);
}
public class RuleBasedWorldDirector : IWorldDirector
{
    public DirectorParameters Parameters(World w) => new(w.creatures.Count(c => c.roach) > 26 ? .35 : 1,
        1 + Math.Min(1, w.interactions / 20), Math.Min(1, w.visibleActivity / 30));
}
public class World
{
    public string migrationMode { get; set; } = "treatment";
    public int reversals
    {
        get; set;
    }
    public int chemicalMigrations
    {
        get; set;
    }
    public ulong eventSerial
    {
        get; set;
    }
    public int capacity { get; set; } = 38;
    public int schema { get; set; } = 1;
    public ulong seed { get; set; } = 42;
    public ulong rng { get; set; } = 42;
    public ulong serial
    {
        get; set;
    }
    public double time
    {
        get; set;
    }
    public double interactions
    {
        get; set;
    }
    public double visibleActivity
    {
        get; set;
    }
    public double mouseCooldown
    {
        get; set;
    }
    public double catCooldown
    {
        get; set;
    }
    public string visitorKind { get; set; } = "";
    public int revision
    {
        get; set;
    }
    public List<WorldHabitat> habitats
    {
        get; set;
    } = [new(), new() { id = "quiet-edge", food = .25, nestability =
        .9 }];
    public List<WorldCreature> creatures { get; set; } = [];
    public List<WorldSignal> signals { get; set; } = [];
    public List<WorldEvent> recentEvents { get; set; } = [];
    public int deaths
    {
        get; set;
    }
    public int migrations
    {
        get; set;
    }
    public int births
    {
        get; set;
    }
    public World()
    {
    }
    public World(ulong seed)
    {
        this.seed = seed;
        rng = seed == 0 ? 1 : seed;
    }
    public double Random()
    {
        rng = unchecked(rng * 1664525 + 1013904223) & 0xffffffff;
        return rng / 4294967296.0;
    }
    public void Event(string entity, string location, string trigger, string previous, string next, string rule)
    {
        recentEvents.Add(new(time, entity, location, trigger, previous, next, rule, ++eventSerial));
        if (recentEvents.Count > 512)
            recentEvents.RemoveRange(0, recentEvents.Count - 512);
    }
    public int Habitat(string id)
    {
        int i = habitats.FindIndex(h => h.id == id);
        if (i >= 0)
            return i;
        if (habitats.Count >= 64)
            return 0;
        habitats.Add(new()
        {
            id = id
        });
        return habitats.Count - 1;
    }
    public string Add(string stage, string location, string? id = null, bool record = true)
    {
        if (creatures.Count >= capacity)
            return "";
        serial++;
        string identity = id ?? $"00000000-0000-4000-8000-{serial:x12}";
        var c = new WorldCreature
        {
            id = identity,
            stage = stage,
            home = location,
            location = location,
            locationMemory = location
        };
        c.boldness = Random();
        c.curiosity = Random();
        c.resistance = Random();
        c.distance = Random();
        c.fertility = .3 + Random() * .7;
        creatures.Add(c);
        if (record)
        {
            Event(identity, location, "created", "absent", stage, "lifecycle");
            births++;
        }
        return identity;
    }
    public void Send(WorldSignal s)
    {
        signals.Add(s);
        if (signals.Count > 128)
            signals.RemoveAt(0);
        revision++;
    }
    public void ApplySignals()
    {
        var pending = signals.ToArray();
        signals.Clear();
        foreach (var s in pending)
        {
            var h = habitats[Habitat(s.location)];
            interactions++;
            switch (s.kind)
            {
                case "visit":
                    double old = h.disturbance;
                    h.disturbance = Math.Min(1, old + .85);
                    h.activity = Math.Min(1, h.activity + .25);
                    h.lastVisited = time;
                    h.stable = 0;
                    Event("habitat", h.id, "visit", old.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        h.disturbance.ToString(System.Globalization.CultureInfo.InvariantCulture), "disturbance");
                    break;
                case "food":
                    h.food = Math.Min(1, h.food + s.amount * .4);
                    Event("habitat", h.id, "food", "",
                        h.food.ToString(System.Globalization.CultureInfo.InvariantCulture), "food");
                    break;
                case "chemical":
                    h.chemical = Math.Min(1, h.chemical + s.amount);
                    Event(s.entity, h.id, "spray", "",
                        h.chemical.ToString(System.Globalization.CultureInfo.InvariantCulture), "chemical");
                    break;
                case "clean":
                    h.food = 0;
                    h.chemical = 0;
                    h.nest = false;
                    h.exposed = false;
                    Event("habitat", h.id, "clean", "nest/residue", "clear", "food");
                    break;
            }
            var c = creatures.Find(c => c.id == s.entity);
            if (c != null)
            {
                if (s.kind == "threat")
                {
                    c.threat = Math.Min(1, c.threat + .3);
                    c.fear = Math.Min(1, c.fear + .3);
                    Event(s.entity, h.id, "player threat", "",
                        c.threat.ToString(System.Globalization.CultureInfo.InvariantCulture), "memory");
                }
                if (s.kind == "friendly")
                {
                    c.friendly = Math.Min(1, c.friendly + .15);
                    c.hunger = Math.Max(0, c.hunger - .2);
                    Event(s.entity, h.id, "player friendly", "",
                        c.friendly.ToString(System.Globalization.CultureInfo.InvariantCulture), "memory");
                }
            }
            if (c != null && !c.protection)
            {
                if (s.kind == "defeat" && c.roach)
                {
                    Event(s.entity, h.id, "manual defeat", c.stage, "corpse", "player");
                    c.stage = "corpse";
                    deaths++;
                }
                if (s.kind == "remove")
                {
                    Event(s.entity, h.id, "vacuum", c.stage, "removed", "player");
                    creatures.Remove(c);
                }
            }
            if (s.kind == "chemical")
                foreach (var c2 in creatures.Where(c => c.location == h.id))
                {
                    c2.playerChemical = true;
                    if (c2.id == s.entity)
                        c2.distance = 0;
                }
        }
    }
    double Preference(WorldHabitat h, WorldCreature c) => h.nestability * .6 + h.food * (.4 + c.hunger) -
        h.disturbance * 1.4 - h.chemical * 2 - h.pressure * .4 + h.safety * .2 + (c.locationMemory == h.id ? .08 : 0);
    public bool MigrationAllowed(WorldCreature c, WorldHabitat h, WorldHabitat destination)
    {
        double advantage = Preference(destination, c) - Preference(h, c);
        if (migrationMode == "control")
            return time >= c.cooldown && destination.id != h.id && Preference(destination, c) > Preference(h, c) + .15;
        bool strong = h.chemical > .6 || c.fear + c.threat > .9 || h.disturbance > .85 || h.pressure > 2;
        double elapsed = c.lastMigrationTime < 0 ? 1e9 : time - c.lastMigrationTime, inertia = .12 * Math.Max(0,
            1 - elapsed / 90);
        return destination.id != h.id && (strong ? advantage > .15 : time >= c.cooldown && elapsed >= 30 &&
            advantage > .30 + inertia);
    }
    public void RecordMigration(WorldCreature c, string destination, double chemical)
    {
        if (c.lastMigrationTime >= 0 && time - c.lastMigrationTime <= 120 && destination == c.previousLocation)
            reversals++;
        if (chemical > .4)
            chemicalMigrations++;
        c.previousLocation = c.location;
        c.lastMigrationTime = time;
    }
    public void Step(double rate = 1, IWorldDirector? director = null)
    {
        const double dt = 2;
        time += dt;
        revision++;
        visitorKind = "";
        ApplySignals();
        var d = (director ?? new RuleBasedWorldDirector()).Parameters(this);
        visibleActivity *= .995;
        foreach (var h in habitats)
        {
            int n = creatures.Count(c => c.roach && c.location == h.id);
            h.pressure = n / 6.0;
            h.disturbance = Math.Max(0, h.disturbance - dt / 120);
            h.activity = Math.Max(0, h.activity - dt / 1800);
            h.food = Math.Max(0, h.food - dt / 18000);
            h.chemical = Math.Max(0, h.chemical - dt / 480);
            h.stable = h.disturbance < .2 && h.chemical < .15 ? h.stable + dt : 0;
            if (!h.nest && n >= 2 && h.stable > 60 && h.nestability > .5 && Random() < dt / 240 * Math.Min(2,
                n / 3.0) * d.pressure)
            {
                h.nest = true;
                Event("nest", h.id, "formation", "absent", "nest", "nest");
            }
        }
        int count = creatures.Count;
        for (int i = 0; i < count; i++)
        {
            var c = creatures[i];
            var h = habitats[Habitat(c.location)];
            if (c.stage == "egg")
            {
                c.age += dt * rate * (h.chemical > .4 ? .4 : 1);
                if (c.age >= 180 && creatures.Count < capacity - 1)
                {
                    c.stage = "hatched";
                    Event(c.id, h.id, "incubation", "egg", "hatched", "lifecycle");
                    for (int n = 0; n < 2; n++)
                    {
                        string baby = Add("baby", h.id);
                        var child = creatures.Find(x => x.id == baby);
                        if (child != null)
                            child.originEgg = c.id;
                    }
                }
                continue;
            }
            if (!c.roach)
                continue;
            c.age += dt * rate;
            c.hunger = Math.Min(1, c.hunger + dt / 1200);
            c.fear = Math.Max(0, c.fear - dt / 240);
            c.threat = Math.Max(0, c.threat - dt / 7200);
            c.energy = Math.Max(.1, c.energy - dt / 2400);
            if (c.stage == "baby" && c.age >= 300)
            {
                c.stage = Random() < .08 * d.rarity ? "gold" : "adult";
                c.age = 0;
                Event(c.id, h.id, "maturation", "baby", c.stage, "lifecycle");
            }
            if (!c.protection && h.safety < .5)
            {
                c.exposure = Math.Max(0, c.exposure + h.chemical * (1 - c.distance * .8) * (1 - c.resistance * .75)
                    * dt / 14 - dt / 300);
                if (c.exposure >= 1)
                {
                    c.stage = "corpse";
                    deaths++;
                    Event(c.id, h.id, "dose", "alive", "corpse", "chemical");
                    continue;
                }
            }
            double alarm = h.disturbance + c.fear + c.threat + h.chemical * (.5 + c.resistance) + d.tension * .1;
            (string intent, double score)[] scores = [("flee", alarm * 1.4 - c.boldness * 1.5), ("hide",
                alarm * (1 - c.boldness) * .8 + .1), ("freeze", h.disturbance * c.boldness * .8), ("eat",
                c.hunger * h.food * 1.8), ("rest", (1 - c.energy) * .9), ("explore",
                c.curiosity * .3 + h.pressure * .32), ("approach", c.friendly * .7 + c.trust * .04 - c.threat),
                ("nest", h.nestability * .3 + (h.nest ? .15 : 0) - h.disturbance), ("idle", .18)];
            string intent = scores.MaxBy(s => s.score).intent;
            if (c.intent != intent)
            {
                Event(c.id, h.id, "utility", c.intent, intent, "utility");
                c.intent = intent;
            }
            var dest = habitats.MaxBy(x => Preference(x, c))!;
            if (MigrationAllowed(c, h, dest) && (intent == "flee" || Random() < dt / 40))
            {
                RecordMigration(c, dest.id, h.chemical);
                string old = c.location;
                c.emergedFrom = old;
                c.location = dest.id;
                c.home = c.location;
                c.locationMemory = c.location;
                c.cooldown = time + 20;
                c.visibleUntil = time + 10;
                migrations++;
                visibleActivity++;
                Event(c.id, c.location, "migration", old, c.location, "preference");
                if (h.nest && !h.exposed)
                {
                    h.exposed = true;
                    Event("nest", h.id, "passing resident", "hidden", "exposed", "pressure");
                }
            }
            else if (intent == "flee" || (intent == "explore" && Random() < dt / 90) || (intent == "approach" &&
                Random() < dt / 60))
            {
                c.visibleUntil = time + 8;
                visibleActivity += .2;
            }
            if (intent is "hide" or "freeze")
                c.visibleUntil = Math.Min(c.visibleUntil, time);
            if (intent == "eat")
            {
                c.hunger = Math.Max(0, c.hunger - dt / 15);
                c.energy = Math.Min(1, c.energy + dt / 60);
                h.food = Math.Max(0, h.food - dt / 500);
            }
            if (intent == "rest")
                c.energy = Math.Min(1, c.energy + dt / 120);
            if (c.stage != "baby" && h.nest && h.stable > 60 && c.hunger < .8 && time >= c.cooldown &&
                creatures.Count < Math.Min(32, capacity - 2) && Random() < dt * rate / 600 * c.fertility * d.pressure)
            {
                Add("egg", h.id);
                c.cooldown = time + 120;
                Event(c.id, h.id, "fertility", "adult", "egg case", "lifecycle");
            }
        }
        creatures.RemoveAll(c => c.stage == "hatched");
        if (interactions > 0 && visibleActivity > .5)
        {
            if (time >= mouseCooldown && Random() < dt / 900 * Math.Min(2, visibleActivity / 4) * d.rarity)
            {
                visitorKind = "mouse";
                mouseCooldown = time + 180;
            }
            if (time >= catCooldown && Random() < dt / 1800 * Math.Min(2, visibleActivity / 8) * d.rarity)
            {
                visitorKind = "catPaw";
                catCooldown = time + 300;
            }
            if (visitorKind.Length > 0)
            {
                Event(visitorKind, "edge", "ecosystem attraction", "absent", "visiting", "visitors");
                foreach (var c in creatures.Where(c => c.roach && !c.protection))
                    c.fear = Math.Min(1, c.fear + .3);
            }
        }
    }
}
