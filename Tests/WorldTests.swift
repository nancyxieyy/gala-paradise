import Foundation
func runWorldTests() {
    runResidueWorldTests()
    var w = World(seed: 7)
    let id = w.add("adult", "edge", record: false)
    w.creatures[0].protected = true
    w.creatures[0].cooldown = 1000
    w.send(WorldSignal(kind: "chemical", entity: id))
    for _ in 0..<200 {
        w.step()
    }
    precondition(w.creatures[0].roach && w.deaths == 0, "Chemical cannot harm protected individuals")
    var game = GameState()
    game.ensureLife()
    let r = Resident(kind: .adult, x: 0, y: 0, born: 0)
    game.residents = [r]
    _ = game.life!.interact(r, action: "name", text: "旧名字", now: 1)
    game.life!.notes = [NoteItem(text: "private")]
    game.life!.cards = ["name.roach": 1]
    var legacy = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as! [String: Any]
    legacy.removeValue(forKey: "world")
    var migrated = try! JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: legacy))
    migrated.ensureWorld()
    migrated.reconcileWorld()
    precondition(
        migrated.world!.recentEvents.isEmpty && migrated.world!.births == 0 && migrated.world!.creatures[0].protected)
    precondition(
        migrated.life!.notes[0].text == "private" && migrated.life!.cards.count == 1
            && migrated.life!.bonds[r.id.uuidString.lowercased()]!.name == "旧名字")
    let defaults = try! JSONDecoder().decode(
        World.self, from: Data("{\"seed\":9,\"habitats\":[{\"id\":\"old\"}],\"creatures\":[{\"id\":\"old\"}]}".utf8))
    precondition(defaults.rng == 9 && defaults.habitats[0].nestability == 0.8 && defaults.creatures[0].energy == 1)
    var before = World(seed: 42)
    _ = before.add("adult", "edge", record: false)
    before.send(WorldSignal(kind: "food"))
    for _ in 0..<50 {
        before.step()
    }
    var resumed = try! JSONDecoder().decode(World.self, from: JSONEncoder().encode(before))
    for _ in 0..<100 {
        before.step()
        resumed.step()
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    precondition(try! encoder.encode(before) == encoder.encode(resumed), "Save resumes PRNG and ecological time")
    migrated.worldSignal("chemical", id: r.id)
    migrated.residents = []
    migrated.stepWorld(rate: 1, now: 10)
    precondition(migrated.residents.isEmpty, "Projection must not resurrect removed identities")
    var chemical = GameState()
    chemical.progression!.owned = Tool.allCases
    chemical.residents = [r]
    chemical.world = World(seed: 4)
    chemical.reconcileWorld()
    chemical.world!.habitats = [WorldHabitat()]
    chemical.world!.creatures[0].cooldown = 1000
    chemical.world!.creatures[0].resistance = 0
    _ = chemical.use(.poison, on: r.id, now: 0, flightRoll: 1)
    for n in 0..<40 {
        chemical.stepWorld(rate: 1, now: Double(n) * 2)
    }
    precondition(chemical.life!.kills == 1 && chemical.captures == 1)
    chemical.stepWorld(rate: 1, now: 100)
    precondition(chemical.life!.kills == 1, "Delayed chemical settlement is exactly once")
    runReadableWorldTests()
    print(
        "PASS: World defaults, legacy identity/notes/cards preservation, no fabricated migration history, protected dose, PRNG resume, no resurrection, chemical rewards exactly once"
    )
}

func runReadableWorldTests() {
    var w = World(seed: 42)
    w.time = 100
    var c = WorldCreature(id: "test", location: "A", locationMemory: "A")
    var a = WorldHabitat(id: "A", food: 0.2)
    var b = WorldHabitat(id: "B", food: 0.9)
    precondition(w.migrationAllowed(c, a, b), "A sustained better habitat remains reachable")
    c.lastMigrationTime = 90
    precondition(!w.migrationAllowed(c, a, b), "Recent commitment prevents routine reversal")
    a.chemical = 0.9
    c.cooldown = 1000
    precondition(w.migrationAllowed(c, a, b), "Chemical interrupts both commitment and breeding cooldown")
    a.chemical = 0
    a.disturbance = 0.9
    precondition(w.migrationAllowed(c, a, b))
    a.disturbance = 0
    c.fear = 1
    precondition(w.migrationAllowed(c, a, b))
    c.fear = 0
    c.cooldown = 0
    c.lastMigrationTime = -1
    b.food = 0.65
    precondition(!w.migrationAllowed(c, a, b), "Small advantage is insufficient")
    w.migrationMode = "control"
    precondition(w.migrationAllowed(c, a, b), "Exact old threshold remains available for control")
    c.previousLocation = "B"
    c.lastMigrationTime = 0
    w.time = 120
    w.recordMigration(&c, to: "B", chemical: 0.7)
    precondition(w.reversals == 1 && w.chemicalMigrations == 1)
    c.location = "B"
    w.time = 242
    w.recordMigration(&c, to: "A", chemical: 0)
    precondition(w.reversals == 1, "122 seconds is outside frozen window")
    let old = try! JSONDecoder().decode(
        World.self, from: Data("{\"creatures\":[{\"id\":\"old\",\"stage\":\"egg\",\"age\":63}]}".utf8))
    precondition(
        old.creatures[0].lastMigrationTime == -1 && old.creatures[0].previousLocation.isEmpty
            && old.creatures[0].age == 63 && old.reversals == 0)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let one = BlindSession(root: root), two = BlindSession(root: root)
    precondition(one.directory != two.directory)
    one.action("name", entity: UUID().uuidString, location: "private-folder")
    one.action("private text")
    one.observe(w)
    try! one.flush()
    let log = try! String(contentsOf: one.directory.appendingPathComponent("observations.jsonl"), encoding: .utf8)
    precondition(!log.contains("private-folder") && !log.contains("private text") && log.contains("worldSeed"))
    try? FileManager.default.removeItem(at: root)
    print(
        "PASS: hysteresis, commitment, emergency interrupt, reversal boundary, missing migration fields, isolated blind log allowlist"
    )
}

func runResidueWorldTests() {
    var inert = World(seed: 7)
    inert.habitats = [WorldHabitat()]
    _ = inert.add("stain", "unknown", record: false)
    inert.step()
    precondition(inert.habitats.count == 1 && inert.births == 0 && inert.ecologicalCount == 0)
    var full = World(seed: 7)
    full.capacity = 2
    _ = full.add("adult", "edge", record: false)
    _ = full.add("adult", "edge", record: false)
    _ = full.add("corpse", "edge", record: false)
    _ = full.add("stain", "edge", record: false)
    precondition(full.ecologicalCount == 2 && full.creatures.count == 4)
    precondition(full.add("egg", "edge").isEmpty)

    var capped = World(seed: 19)
    for _ in 0..<25 {
        _ = capped.add("stain", "edge", record: false)
    }
    let oldest = capped.creatures[0].id
    capped.creatures[0].residueAge = 100
    capped.limitResidues()
    precondition(capped.creatures.count == 24 && !capped.creatures.contains { $0.id == oldest })
    let corpse = capped.add("corpse", "edge", record: false)
    capped.limitResidues()
    precondition(!capped.creatures.contains { $0.id == corpse })
    precondition(capped.recentEvents.allSatisfy { $0.rule == "residue-cap" })

    var order = World(seed: 19)
    for _ in 0..<25 {
        _ = order.add("corpse", "edge", record: false)
    }
    let oldestCorpse = order.creatures[17].id
    order.creatures[17].residueAge = 590
    order.limitResidues()
    precondition(order.creatures.count == 24 && !order.creatures.contains { $0.id == oldestCorpse })
    var drying = World(seed: 7), control = World(seed: 7)
    drying.habitats = [WorldHabitat()]
    control.habitats = drying.habitats
    _ = drying.add("corpse", "edge", record: false)
    for _ in 0..<299 {
        drying.step(rate: 3)
        control.step(rate: 3)
    }
    precondition(drying.creatures[0].residueAge == 598)
    drying.step(rate: 3)
    control.step(rate: 3)
    precondition(drying.creatures.isEmpty && drying.deaths == 0 && drying.births == 0)
    precondition(abs(drying.habitats[0].food - control.habitats[0].food - World.corpseFood) < 1e-10)
    precondition(drying.recentEvents.filter { $0.trigger == "decay" && $0.rule == "residue" }.count == 1)
    let old = try! JSONDecoder().decode(World.self,
        from: Data("{\"creatures\":[{\"id\":\"old\",\"stage\":\"corpse\",\"age\":90000}]}".utf8))
    precondition(old.creatures[0].residueAge == 0 && !old.creatures[0].dormant)

    var dormant = World(seed: 42)
    dormant.capacity = 3
    _ = dormant.add("egg", "edge", record: false)
    let a = dormant.add("adult", "edge", record: false)
    let b = dormant.add("adult", "edge", record: false)
    dormant.creatures[0].age = 178
    for _ in 0..<10 {
        dormant.step()
    }
    precondition(dormant.creatures[0].age == 180 && dormant.creatures[0].dormant)
    precondition(dormant.recentEvents.filter { $0.trigger == "dormant" }.count == 1)
    var resumed = try! JSONDecoder().decode(World.self, from: JSONEncoder().encode(dormant))
    resumed.step()
    precondition(resumed.recentEvents.filter { $0.trigger == "dormant" }.count == 1)
    resumed.send(WorldSignal(kind: "remove", entity: a))
    resumed.send(WorldSignal(kind: "remove", entity: b))
    resumed.step()
    precondition(resumed.creatures.count == 2 && resumed.creatures.allSatisfy { $0.stage == "baby" })

    var game = GameState()
    game.world = World(seed: 7)
    for _ in 0..<38 {
        game.residents.append(Resident(kind: .adult, x: 0, y: 0, born: 0))
    }
    game.residents.append(Resident(kind: .corpse, x: 0, y: 0, born: 0))
    game.residents.append(Resident(kind: .stain, x: 0, y: 0, born: 0))
    game.reconcileWorld()
    precondition(game.world!.ecologicalCount == 38 && game.world!.creatures.count == 40)
    for n in 0..<300 {
        game.stepWorld(rate: 1, now: Double(n) * 2)
    }
    precondition(game.residents.count == 39 && game.residents.contains { $0.kind == .stain })
    precondition(game.captures == 0 && game.cleaned == 0 && game.xp == 0)
    precondition(game.life!.kills == 0 && game.life!.cards.isEmpty && game.progression!.shells == 0)
    var loaded = GameState()
    loaded.residents = (0..<24).map { _ in Resident(kind: .stain, x: 0, y: 0, born: 0) }
        + (0..<40).map { _ in Resident(kind: .adult, x: 0, y: 0, born: 0) }
    loaded.limitPopulation()
    precondition(loaded.populationCount == 38 && loaded.residents.count == 62)
    print("PASS: residue quotas, eviction, decay food/timing, legacy defaults, dormant resume, full bridge, no rewards")
}
