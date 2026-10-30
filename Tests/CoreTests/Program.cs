using Gala;
using System.Drawing;
static void Check(bool ok, string name)
{
    if (!ok)
        throw new Exception(name);
    Console.WriteLine("PASS: " + name);
}
var g = new Game(100, 7) { EnableEncounters = false };
var r = g.Spawn(Kind.Adult, 100)!;
g.Select(Tool.Vacuum);
Check(g.State.Tool == Tool.Pinch, "locked tools");
g.Use(r.Id, 101, 0);
Check(r.FlyingUntil == 103.8 && g.State.Captures == 0, "flight escape");
g.Use(r.Id, 102, 1);
Check(r.Live, "cannot hit airborne roach");
g.Use(r.Id, 104, 1);
Check(r.Kind == Kind.Stain && g.State.Xp == 2, "pinch leaves persistent stain");
g.State.Xp = 28;
g.State.Progression.Owned = Enum.GetValues<Tool>().ToList();
g.Select(Tool.Vacuum);
g.Use(r.Id, 105);
Check(g.State.Residents.Contains(r), "vacuum cannot erase stain");
g.Select(Tool.Cleaner);
g.Use(r.Id, 106);
Check(g.State.Residents.Count == 0, "cleaner removes stain");
foreach (var k in new[] { Kind.Egg, Kind.Corpse, Kind.Adult, Kind.Baby })
{
    r = g.Spawn(k, 110)!;
    r.FlyingUntil = 200;
    g.Select(Tool.Vacuum);
    g.Use(r.Id, 111);
    Check(!g.State.Residents.Contains(r), "vacuum " + k);
}
g.Select(Tool.Poison);
int beforeFolder = g.State.Residents.Count;
g.Folder(120);
Check(g.State.Residents.Count == beforeFolder && g.State.World!.signals.Any(s => s.kind == "visit"),
    "folder produces habitat signal without spawning");
var copy = new Game(180) { EnableEncounters = false };
copy.Restore(g.Serialize());
Check(copy.State.Xp == g.State.Xp && copy.State.Poisoned && copy.State.Residents.Count == g.State.Residents.Count &&
    copy.State.Residents.Where(r => r.Live).All(r => r.Hidden), "persistent progress and hidden reload");
var visit = new Game(100, 2) { EnableEncounters = false };
visit.Screens = [new(-1440, 0, 1440, 900)];
r = visit.Spawn(Kind.Adult, 100)!;
Check(!r.Hidden, "edge appearance");
double now = 100;
for (int i = 0; i < 3000 && !r.Hidden; i++)
{
    now += 1.0 / 30;
    visit.Tick(now, 1.0 / 30);
}
Check(r.Hidden, "walk then completely leave screen");
visit.Tick(now + 10, 0);
Check(r.Hidden, "empty screen interval");
visit.State.Quiet = true;
visit.Tick(now + 100, 0);
Check(r.Hidden, "focus prevents reappearance");
visit.TogglePause(now + 101);
var before = r.X;
visit.Tick(now + 200, 1);
Check(r.X == before && visit.Paused, "pause freezes simulation");
visit.TogglePause(now + 201);
Check(!visit.Paused && r.Hidden, "resume preserves hiding");
var survivor = new Game(100) { EnableEncounters = false };
survivor.Tick(101, 0);
survivor.Tick(126, 0);
Check(survivor.State.Residents.Count == 0, "extinction does not create scripted survivor");
for (int i = 0; i < 100; i++)
    survivor.Spawn(Kind.Adult, 127);
Check(survivor.State.Residents.Count == 38, "population cap");
Console.WriteLine("All Windows gameplay model tests passed on this host.");

var f = new Rectangle(100, 100, 800, 500);
for (int i = 0; i < 4; i++)
{
    var p = Habitat.Border(f, i, .5);
    Check(p.X + 55 == f.Left || p.X + 55 == f.Right || p.Y + 85 == f.Top || p.Y + 85 == f.Bottom, "window border " + i);
}
var clean = new Game(100) { EnableEncounters = false };
clean.State.Xp = 28;
clean.State.Progression.Owned = Enum.GetValues<Tool>().ToList();
var stain = clean.Spawn(Kind.Stain, 100);
clean.Spawn(Kind.Egg, 100);
clean.Scan(101);
clean.Tick(160, 1);
Check(clean.State.Residents.Count == 1 && clean.State.Residents[0] == stain,
    "scan preserves manual stain cleanup and prevents growth");

var slow = new Game(100) { EnableEncounters = false };
slow.State.Habitat.Rate = .25;
slow.Spawn(Kind.Egg, 100);
var fast = new Game(100) { EnableEncounters = false };
fast.State.Habitat.Rate = 3;
fast.Spawn(Kind.Egg, 100);
for (int i = 1; i <= 100; i++)
{
    slow.Tick(100 + i, 1);
    fast.Tick(100 + i, 1);
}
Check(slow.State.Residents.Any(r => r.Kind == Kind.Egg) && fast.State.Residents.Any(r => r.Kind == Kind.Baby),
    "growth rate changes hatch time, not walking speed");

var economy = new Game(100) { EnableEncounters = false };
economy.State.Xp = 100;
Check(!economy.Owns(Tool.Poison), "XP no longer buys tools");
economy.State.Progression.Shells = 4;
economy.Select(Tool.Poison);
Check(economy.Owns(Tool.Poison) && economy.State.Progression.Shells == 0, "shell purchase");
economy.Select(Tool.Poison);
Check(economy.State.Progression.Shells == 0, "no repeat purchase");
var gold = economy.Spawn(Kind.Gold, 100)!;
economy.Select(Tool.Pinch);
economy.Use(gold.Id, 101, 1);
economy.Use(gold.Id, 102, 1);
Check(economy.State.Progression.Shells == 2, "gold gives exactly one reward");
var friend = economy.Spawn(Kind.Mouse, 100)!;
economy.Use(friend.Id, 102, 1);
Check(friend.Kind == Kind.Mouse, "friends cannot be killed with tools");
var guests = new Game(100);
guests.State.Progression.Played = 100000;
guests.StepWorld(100);
Check(!guests.State.Residents.Any(r => r.Friend), "playtime alone cannot create visitors");
var legacy = System.Text.Json.Nodes.JsonNode.Parse(economy.Serialize())!;
legacy.AsObject().Remove("Progression");
var migrated = new Game(100);
migrated.Restore(legacy.ToJsonString());
Check(migrated.Owns(Tool.Cleaner), "legacy XP tools survive migration");

Check(Rules.PawContact(0) == 0 && Rules.PawContact(3) == 1 && Rules.PawContact(6) == 0,
    "paw reach, planted hold, withdrawal");
var pawGame = new Game(100) { EnableEncounters = false };
var paw = pawGame.Spawn(Kind.CatPaw, 100)!;
paw.Hidden = false;
paw.X = 400;
paw.Y = 200;
pawGame.Tick(103, 3);
Check(paw.X == 400 && paw.Y == 200 && !paw.Hidden, "paw remains anchored on desktop");
pawGame.Tick(106, 3);
Check(paw.Hidden, "paw withdraws after six seconds while retaining familiar identity");
var living = new Life();
var buddy = new Resident { Kind = Kind.Adult };
for (int i = 0; i < 6; i++)
    living.Interact(buddy, "pet", "", i * 21);
living.Interact(buddy, "bond", "", 130);
Check(living.Protects(buddy.Id), "trusted resident becomes protected partner");
int trust = living.Bonds[buddy.Id.ToString()].Trust;
living.Interact(buddy, "feed", "", 106);
Check(living.Bonds[buddy.Id.ToString()].Trust == trust, "interaction cooldown");
Check(living.Gold(buddy.Id, 140) == 2 && living.Gold(buddy.Id, 141) == 0,
    "gold reward idempotent across friendly and hostile actions");
string adoption = living.Share(buddy.Id, 150)!;
Check(living.Adopt(adoption, 151).Resident != null && living.Adopt(adoption, 152).Resident == null,
    "adoption duplicate prevented");
Check(living.Adopt("GALA1:invalid", 153).Resident == null, "malformed adoption rejected");
living.Stash("private note", 160);
Check(living.Notes.Count == 1 && !adoption.Contains("private note"), "stash remains separate from sharing");
living.FocusRemaining = 1;
Check(living.Tick(1, 170) && living.Cards.ContainsKey("focus.first"), "focus completion awards card");
var protectGame = new Game(100) { EnableEncounters = false };
protectGame.State.Life = living;
protectGame.State.Residents.Add(buddy);
protectGame.Use(buddy.Id, 180, 1);
Check(buddy.Live, "tools cannot harm partner");
protectGame.State.Progression.Owned.Add(Tool.Poison);
protectGame.Scan(181);
Check(protectGame.State.Residents.Contains(buddy), "scan preserves partner");
var savedLife = new Game(100);
savedLife.Restore(protectGame.Serialize());
Check(savedLife.State.Life.Notes.Count == 1 && savedLife.State.Life.Protects(buddy.Id), "life save roundtrip");
var route = new Game(100) { EnableEncounters = false };
double actionNow = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
var ranger = route.Spawn(Kind.Mouse, actionNow)!;
route.State.Life.Observe(ranger, actionNow);
route.State.Life.Bonds[ranger.Id.ToString()].Trust = 6;
route.State.Life.Interact(ranger, "bond", "", actionNow);
var wild = route.Spawn(Kind.Adult, actionNow)!;
wild.X = 1000;
wild.Y = 200;
wild.Hidden = false;
var named = route.Spawn(Kind.Adult, actionNow)!;
named.X = 1100;
named.Hidden = false;
route.State.Life.Interact(named, "name", "阿强", actionNow);
route.LifeAction("patrol", ranger.Id, "", null);
Check(wild.Hidden && !named.Hidden && route.State.Life.Cards.ContainsKey("patrol.first"),
    "patrol drives wild residents but preserves named partners");
Check(route.State.Captures == 0 && route.State.Life.Kills == 0, "patrol grants no kill or capture rewards");
route.LifeAction("focus", null, "", null, 1);
int population = route.State.Residents.Count;
route.Folder(actionNow + 2);
route.Feed(actionNow + 2);
route.Tick(actionNow + 2, .1);
Check(route.State.Residents.All(r => !r.Live || r.Hidden) && route.State.Residents.Count == population,
    "timed focus suppresses folder and feeding encounters");
route.LifeAction("cancel", null, "", null);
Check(!route.State.Life.Cards.ContainsKey("focus.first"), "cancelled focus does not award completion");
var oldJson = System.Text.Json.Nodes.JsonNode.Parse(route.Serialize())!;
oldJson.AsObject().Remove("Life");
var oldLoad = new Game(100);
oldLoad.Restore(oldJson.ToJsonString());
Check(oldLoad.State.Residents.Count == population && oldLoad.State.Life.Cards.Count == 0,
    "pre-1.5 saves initialize handbook without losing residents");
foreach (var species in new[] { Kind.Mouse, Kind.CatPaw })
{
    var clickGame = new Game(100) { EnableEncounters = false };
    clickGame.State.Progression.Owned = Enum.GetValues<Tool>().ToList();
    var actor = clickGame.Spawn(species, 100)!;
    foreach (var tool in Enum.GetValues<Tool>())
    {
        clickGame.State.Tool = tool;
        clickGame.Use(actor.Id, 200 + (int)tool * 21, 1);
        Check(actor.Live && actor.ReactionUntil > 200 + (int)tool * 21 &&
            !string.IsNullOrEmpty(clickGame.Message) && clickGame.State.Captures == 0,
            $"{species} reacts to {tool} without being harmed");
    }
    clickGame.State.Tool = Tool.Pinch;
    clickGame.Use(actor.Id, 1000, 1);
    int relationship = clickGame.State.Life.Bonds[actor.Id.ToString()].Trust;
    clickGame.Use(actor.Id, 1001, 1);
    Check(clickGame.State.Life.Bonds[actor.Id.ToString()].Trust == relationship,
        "repeat click responds without farming trust");
    actor.Hidden = false;
    actor.X = 150;
    actor.HoldUntil = 1010;
    clickGame.Tick(1002, .1);
    Check(actor.X == 150 && !actor.Hidden, "hover hold keeps animal clickable");
    float position = actor.X;
    clickGame.LifeAction("pet", actor.Id, "", null, inPlace: true);
    Check(actor.X == position, "right click interaction does not teleport animal");
}

var dose = new World(7);
var doseID = dose.Add("adult", "edge", record: false);
dose.creatures[0].protection = true;
dose.creatures[0].cooldown = 1000;
dose.Send(new("chemical", entity: doseID));
for (int i = 0; i < 200; i++)
    dose.Step();
Check(dose.creatures[0].roach && dose.deaths == 0, "chemical never harms protected identity");
var oldWorldJson = System.Text.Json.Nodes.JsonNode.Parse(protectGame.Serialize())!;
oldWorldJson.AsObject().Remove("World");
var worldMigration = new Game(100);
worldMigration.Restore(oldWorldJson.ToJsonString());
worldMigration.EnsureWorld();
worldMigration.ReconcileWorld();
Check(worldMigration.State.World!.recentEvents.Count == 0 && worldMigration.State.World.births == 0 &&
    worldMigration.State.Life.Notes.Count == 1 && worldMigration.State.World.creatures[0].protection,
    "world migration preserves partner/notes without invented events");
var chem = new Game(0, 4);
var victim = chem.Spawn(Kind.Adult, 0)!;
chem.State.Progression.Owned = Enum.GetValues<Tool>().ToList();
chem.ReconcileWorld();
chem.State.World!.habitats = [new WorldHabitat()];
chem.State.World.creatures[0].cooldown = 1000;
chem.State.World.creatures[0].resistance = 0;
chem.State.Tool = Tool.Poison;
chem.Use(victim.Id, 0);
for (int i = 0; i < 40; i++)
    chem.StepWorld(i * 2);
Check(chem.State.Life.Kills == 1 && chem.State.Captures == 1, "delayed chemical awards one defeat");
chem.StepWorld(100);
Check(chem.State.Life.Kills == 1, "chemical defeat is not paid twice");

var stableWorld = new World(42) { time = 100 };
var chooser = new WorldCreature { id = "test", location = "A", locationMemory = "A" };
var source = new WorldHabitat { id = "A", food = .2 };
var destination = new WorldHabitat { id = "B", food = .9 };
Check(stableWorld.MigrationAllowed(chooser, source, destination), "better habitat remains reachable");
chooser.lastMigrationTime = 90;
Check(!stableWorld.MigrationAllowed(chooser, source, destination), "commitment prevents routine reversal");
source.chemical = .9;
chooser.cooldown = 1000;
Check(stableWorld.MigrationAllowed(chooser, source, destination),
    "chemical interrupts commitment and breeding cooldown");
source.chemical = 0;
source.disturbance = .9;
Check(stableWorld.MigrationAllowed(chooser, source, destination), "extreme disturbance interrupts");
source.disturbance = 0;
chooser.fear = 1;
Check(stableWorld.MigrationAllowed(chooser, source, destination), "threat interrupts");
chooser.fear = 0;
chooser.cooldown = 0;
chooser.lastMigrationTime = -1;
destination.food = .65;
Check(!stableWorld.MigrationAllowed(chooser, source, destination), "small advantage rejected");
stableWorld.migrationMode = "control";
Check(stableWorld.MigrationAllowed(chooser, source, destination), "control retains old threshold");
chooser.previousLocation = "B";
chooser.lastMigrationTime = 0;
stableWorld.time = 120;
stableWorld.RecordMigration(chooser, "B", .7);
Check(stableWorld.reversals == 1 && stableWorld.chemicalMigrations == 1, "reversal inclusive 120-second boundary");
chooser.location = "B";
stableWorld.time = 242;
stableWorld.RecordMigration(chooser, "A", 0);
Check(stableWorld.reversals == 1, "122 seconds outside reversal window");
var oldReadable =
    System.Text.Json.JsonSerializer.Deserialize<World>(
        "{\"creatures\":[{\"id\":\"old\",\"stage\":\"egg\",\"age\":63}]}")!;
Check(oldReadable.creatures[0].lastMigrationTime == -1 && oldReadable.creatures[0].previousLocation == "" &&
    oldReadable.creatures[0].age == 63 && oldReadable.reversals == 0,
    "missing fields never invent migration history or offline age");
var continuation = new World(42);
continuation.Add("adult", "edge", record: false);
for (int i = 0; i < 50; i++)
    continuation.Step();
var restoredWorld =
    System.Text.Json.JsonSerializer.Deserialize<World>(System.Text.Json.JsonSerializer.Serialize(continuation))!;
for (int i = 0; i < 100; i++)
{
    continuation.Step();
    restoredWorld.Step();
}
Check(System.Text.Json.JsonSerializer.Serialize(continuation) ==
    System.Text.Json.JsonSerializer.Serialize(restoredWorld), "new migration state and PRNG survive resume");
string blindRoot = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
var sessionOne = new BlindSession(blindRoot);
var sessionTwo = new BlindSession(blindRoot);
Check(sessionOne.DirectoryPath != sessionTwo.DirectoryPath, "fresh blind session directories");
sessionOne.Action("name", Guid.NewGuid().ToString(), "private-folder");
sessionOne.Action("private text");
sessionOne.Observe(stableWorld);
sessionOne.Flush();
string blindLog = File.ReadAllText(Path.Combine(sessionOne.DirectoryPath, "observations.jsonl"));
Check(!blindLog.Contains("private-folder") && !blindLog.Contains("private text") && blindLog.Contains("worldSeed"),
    "blind log excludes names, user text and raw habitat identity");
Directory.Delete(blindRoot, true);
var visualGame = new Game(0, 42);
var visualWorld = new World(42) { habitats = [new() { id = "A", chemical = .9 }, new() { id = "B" }] };
string visualID = visualWorld.Add("adult", "A", record: false);
visualWorld.creatures[0].boldness = 0;
visualGame.State.World = visualWorld;
var visualResident = new Resident
{
    Id = Guid.Parse(visualID),
    Kind = Kind.Adult,
    X = 220,
    Y = 180,
    Hidden = false,
    Screen = visualGame.Screens[0],
    ExitAt = 100
};
visualGame.State.Residents.Add(visualResident);
visualGame.StepWorld(0);
Check(visualWorld.migrations == 1 && visualGame.MigrationViews.ContainsKey(visualResident.Id) &&
    visualResident.Exiting && visualResident.X == 220 && visualResident.Y == 180,
    "Windows projection starts departure without teleport");
Check(visualGame.ReadableCues["habitat:A"].Chemical > .8, "Windows persistent chemical snapshot");
var hatchGame = new Game(0, 9);
var hatchWorld = new World(9) { habitats = [new() { id = "A" }] };
string parentEgg = hatchWorld.Add("egg", "A", record: false);
hatchWorld.creatures[0].age = 178;
hatchGame.State.World = hatchWorld;
hatchGame.State.Residents.Add(new() { Id = Guid.Parse(parentEgg), Kind = Kind.Egg, X = 340, Y = 160 });
hatchGame.StepWorld(0);
Check(hatchGame.State.Residents.Count == 2 && hatchGame.State.Residents.All(r => r.Kind == Kind.Baby && r.X ==
    340 && r.Y == 160) && hatchWorld.creatures.All(c => c.originEgg == parentEgg),
    "Windows juveniles keep actual egg origin");
Check(hatchGame.ReadableCues.ContainsKey("shell:" + parentEgg), "Windows empty shell exists only after actual hatch");

var residueFull = new World(7) { capacity = 2 };
residueFull.Add("adult", "edge", record: false);
residueFull.Add("adult", "edge", record: false);
residueFull.Add("corpse", "edge", record: false);
residueFull.Add("stain", "edge", record: false);
Check(residueFull.EcologicalCount == 2 && residueFull.creatures.Count == 4 &&
    residueFull.Add("egg", "edge") == "", "residue is independent of ecological quota");
var residueCapped = new World(19);
for (int i = 0; i < 25; i++) residueCapped.Add("stain", "edge", record: false);
string oldestStain = residueCapped.creatures[0].id;
residueCapped.creatures[0].residueAge = 100;
residueCapped.LimitResidues();
Check(residueCapped.creatures.Count == 24 && residueCapped.creatures.All(c => c.id != oldestStain),
    "oldest stain is evicted when no corpse exists");
string priorityCorpse = residueCapped.Add("corpse", "edge", record: false);
residueCapped.LimitResidues();
Check(residueCapped.creatures.All(c => c.id != priorityCorpse) &&
    residueCapped.recentEvents.All(e => e.rule == "residue-cap"), "corpse eviction precedes any stain");
var residueDrying = new World(7) { habitats = [new()] };
var residueControl = new World(7) { habitats = [new()] };
residueDrying.Add("corpse", "edge", record: false);
for (int i = 0; i < 299; i++)
{
    residueDrying.Step(3);
    residueControl.Step(3);
}
Check(residueDrying.creatures[0].residueAge == 598, "decay uses active seconds independent of growth rate");
residueDrying.Step(3);
residueControl.Step(3);
Check(residueDrying.creatures.Count == 0 && residueDrying.deaths == 0 && residueDrying.births == 0 &&
    Math.Abs(residueDrying.habitats[0].food - residueControl.habitats[0].food - World.corpseFood) < 1e-10,
    "corpse decays at 600 and contributes .25 food");
Check(residueDrying.recentEvents.Count(e => e.trigger == "decay" && e.rule == "residue") == 1,
    "natural decay produces exactly one residue event");
var residueOld = System.Text.Json.JsonSerializer.Deserialize<World>(
    "{\"creatures\":[{\"id\":\"old\",\"stage\":\"corpse\",\"age\":90000}]}")!;
Check(residueOld.creatures[0].residueAge == 0 && !residueOld.creatures[0].dormant,
    "old corpses start at zero active decay age");
var eggDormancy = new World(42) { capacity = 3 };
eggDormancy.Add("egg", "edge", record: false);
string dormAdultA = eggDormancy.Add("adult", "edge", record: false);
string dormAdultB = eggDormancy.Add("adult", "edge", record: false);
eggDormancy.creatures[0].age = 178;
for (int i = 0; i < 10; i++) eggDormancy.Step();
Check(eggDormancy.creatures[0].age == 180 && eggDormancy.creatures[0].dormant &&
    eggDormancy.recentEvents.Count(e => e.trigger == "dormant") == 1, "mature eggs sleep and log once");
var dormResumed = System.Text.Json.JsonSerializer.Deserialize<World>(
    System.Text.Json.JsonSerializer.Serialize(eggDormancy))!;
dormResumed.Step();
Check(dormResumed.recentEvents.Count(e => e.trigger == "dormant") == 1, "dormancy survives save without relogging");
dormResumed.Send(new("remove", "edge", dormAdultA));
dormResumed.Send(new("remove", "edge", dormAdultB));
dormResumed.Step();
Check(dormResumed.creatures.Count == 2 && dormResumed.creatures.All(c => c.stage == "baby"),
    "free capacity hatches sleeping egg on the next step");
var residueGame = new Game(0, 7) { EnableEncounters = false };
residueGame.State.World = new World(7);
for (int i = 0; i < 38; i++) residueGame.State.Residents.Add(new() { Kind = Kind.Adult });
residueGame.State.Residents.Add(new() { Kind = Kind.Corpse });
residueGame.State.Residents.Add(new() { Kind = Kind.Stain });
residueGame.ReconcileWorld();
Check(residueGame.State.World.EcologicalCount == 38 && residueGame.State.World.creatures.Count == 40,
    "full bridge preserves residual residents");
for (int i = 0; i < 300; i++) residueGame.StepWorld(i * 2);
Check(residueGame.State.Residents.Count == 39 && residueGame.State.Residents.Any(r => r.Kind == Kind.Stain) &&
    residueGame.State.Captures == 0 && residueGame.State.Cleaned == 0 && residueGame.State.Xp == 0 &&
    residueGame.State.Progression.Shells == 0 && residueGame.State.Life.Cards.Count == 0 &&
    residueGame.State.Life.Kills == 0, "natural decay grants no player rewards or achievements");
var residueLoaded = new Game(0, 7);
for (int i = 0; i < 24; i++) residueLoaded.State.Residents.Add(new() { Kind = Kind.Stain });
for (int i = 0; i < 40; i++) residueLoaded.State.Residents.Add(new() { Kind = Kind.Adult });
residueLoaded.Restore(residueLoaded.Serialize());
Check(residueLoaded.PopulationCount == 38 && residueLoaded.State.Residents.Count == 62,
    "loading limits population independently from earlier residue rows");

var residueOrder = new World(19);
for (int i = 0; i < 25; i++) residueOrder.Add("corpse", "edge", record: false);
string oldestCorpseID = residueOrder.creatures[17].id;
residueOrder.creatures[17].residueAge = 590;
residueOrder.LimitResidues();
Check(residueOrder.creatures.Count == 24 && residueOrder.creatures.All(c => c.id != oldestCorpseID),
    "oldest corpse is selected even when later in array");
var freezeResidue = new Game(0, 7);
freezeResidue.State.Residents.Add(new() { Kind = Kind.Corpse });
freezeResidue.ReconcileWorld();
freezeResidue.Paused = true;
freezeResidue.Tick(10, .1);
Check(freezeResidue.State.World!.creatures[0].residueAge == 0, "pause does not advance corpse age");
freezeResidue.Paused = false;
freezeResidue.State.Life.FocusRemaining = 60;
freezeResidue.Tick(11, .1);
Check(freezeResidue.State.World!.creatures[0].residueAge == 0, "focus does not advance corpse age");
var sleepingProjection = new Game(0, 7);
sleepingProjection.State.World = eggDormancy;
sleepingProjection.State.Residents = eggDormancy.creatures.Select(c => new Resident
{
    Id = Guid.Parse(c.id), Kind = c.stage == "egg" ? Kind.Egg : Kind.Adult
}).ToList();
sleepingProjection.ProjectReadable(sleepingProjection.State.Residents.ToDictionary(r => r.Id), 0);
Check(sleepingProjection.State.Residents.First(r => r.Kind == Kind.Egg).EggDormant,
    "dormant appearance is projected from model");

var inertStain = new World(7) { habitats = [new()] };
inertStain.Add("stain", "unknown", record: false);
inertStain.Step();
Check(inertStain.habitats.Count == 1 && inertStain.births == 0 && inertStain.EcologicalCount == 0,
    "stain cannot create ecological habitats or affect occupancy");
