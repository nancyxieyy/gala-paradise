import Foundation

// V0: ecological time is active simulation time, never wall clock or offline elapsed time.
struct WorldHabitat: Codable {
    var id = "edge"
    var disturbance = 0.0, activity = 0.0, food = 0.35, nestability = 0.8, chemical = 0.0, safety = 0.0, pressure = 0.0,
        lastVisited = 0.0, stable = 0.0
    var nest = false, exposed = false, discovered = false
}
struct WorldCreature: Codable {
    var id = "", stage = "adult", home = "edge", location = "edge", intent = "idle", locationMemory = "edge",
        emergedFrom = "edge"
    var age = 0.0, energy = 1.0, hunger = 0.2, fear = 0.0, curiosity = 0.5, boldness = 0.5, fertility = 0.6, trust = 0.0
    var threat = 0.0, friendly = 0.0, exposure = 0.0, resistance = 0.5, distance = 0.5, cooldown = 0.0,
        visibleUntil = 0.0
    var residueAge = 0.0
    var dormant = false
    var lastMigrationTime = -1.0
    var previousLocation = "", originEgg = ""
    var protected = false, playerChemical = false
    var roach: Bool {
        ["adult", "baby", "gold"].contains(stage)
    }
}
struct WorldEvent: Codable {
    var sequence: UInt64?
    var timestamp: Double
    var entity: String
    var location: String
    var trigger: String
    var previous: String
    var new: String
    var rule: String
}
struct WorldSignal: Codable {
    var kind: String
    var location: String = "edge"
    var entity: String = ""
    var amount: Double = 1
}
struct DirectorParameters {
    var pressure = 1.0, rarity = 1.0, tension = 0.0
}
protocol IWorldDirector {
    func parameters(_ world: World) -> DirectorParameters
}
struct RuleBasedWorldDirector: IWorldDirector {
    func parameters(_ w: World) -> DirectorParameters {
        DirectorParameters(
            pressure: w.creatures.filter {
                $0.roach
            }.count > 26 ? 0.35 : 1, rarity: 1 + min(1, w.interactions / 20),
            tension: min(1, w.visibleActivity / 30))
    }
}
struct World: Codable {
    static let corpseDecay = 600.0
    static let corpseFood = 0.25
    static let residueCap = 24
    var ecologicalCount: Int {
        creatures.filter { $0.roach || $0.stage == "egg" }.count
    }
    mutating func limitResidues() {
        while creatures.filter({ ["corpse", "stain"].contains($0.stage) }).count > Self.residueCap {
            let stage = creatures.contains { $0.stage == "corpse" } ? "corpse" : "stain"
            var oldest: Int?
            for i in creatures.indices where creatures[i].stage == stage {
                if oldest == nil || creatures[i].residueAge > creatures[oldest!].residueAge {
                    oldest = i
                }
            }
            let c = creatures.remove(at: oldest!)
            event(c.id, c.location, "evicted", c.stage, "removed", "residue-cap")
        }
    }
    mutating func advanceResidues(_ dt: Double) {
        for i in creatures.indices where ["corpse", "stain"].contains(creatures[i].stage) {
            creatures[i].residueAge += dt
            if creatures[i].stage == "corpse" {
                let h = habitat(creatures[i].location)
                habitats[h].food = min(1, habitats[h].food + Self.corpseFood * dt / Self.corpseDecay)
            }
        }
        for c in creatures where c.stage == "corpse" && c.residueAge >= Self.corpseDecay {
            event(c.id, c.location, "decay", "corpse", "removed", "residue")
        }
        creatures.removeAll { $0.stage == "corpse" && $0.residueAge >= Self.corpseDecay }
    }
    var migrationMode = "treatment"
    var reversals = 0, chemicalMigrations = 0
    var capacity = 38
    var eventSerial: UInt64 = 0
    var schema = 1
    var seed: UInt64 = 42, rng: UInt64 = 42, serial: UInt64 = 0
    var time = 0.0, interactions = 0.0, visibleActivity = 0.0, mouseCooldown = 0.0, catCooldown = 0.0, visitorKind = "",
        revision = 0
    var habitats: [WorldHabitat] = [WorldHabitat(), WorldHabitat(id: "quiet-edge", food: 0.25, nestability: 0.9)]
    var creatures: [WorldCreature] = []
    var signals: [WorldSignal] = []
    var recentEvents: [WorldEvent] = []
    var deaths = 0, migrations = 0, births = 0
    init(seed: UInt64 = 42) {
        self.seed = seed
        self.rng = seed == 0 ? 1 : seed
    }
    mutating func random() -> Double {
        rng = (rng &* 1664525 &+ 1013904223) & 0xffffffff
        return Double(rng) / 4294967296.0
    }
    mutating func event(
        _ entity: String, _ location: String, _ trigger: String, _ previous: String, _ new: String, _ rule: String
    ) {
        eventSerial += 1
        recentEvents.append(
            WorldEvent(
                sequence: eventSerial, timestamp: time, entity: entity, location: location, trigger: trigger,
                previous: previous, new: new, rule: rule))
        if recentEvents.count > 512 {
            recentEvents.removeFirst(recentEvents.count - 512)
        }
    }
    mutating func habitat(_ id: String) -> Int {
        if let i = habitats.firstIndex(where: {
            $0.id == id
        }) {
            return i
        }
        if habitats.count >= 64 {
            return 0
        }
        habitats.append(WorldHabitat(id: id))
        return habitats.count - 1
    }
    mutating func add(_ stage: String, _ location: String, id: String? = nil, record: Bool = true) -> String {
        guard ["corpse", "stain"].contains(stage) || ecologicalCount < capacity else {
            return ""
        }
        serial += 1
        let identity = id ?? String(format: "00000000-0000-4000-8000-%012llx", serial)
        var c = WorldCreature(id: identity, stage: stage, home: location, location: location, locationMemory: location)
        c.boldness = random()
        c.curiosity = random()
        c.resistance = random()
        c.distance = random()
        c.fertility = 0.3 + random() * 0.7
        creatures.append(c)
        if record {
            event(identity, location, "created", "absent", stage, "lifecycle")
            births += 1
        }
        return identity
    }
    mutating func send(_ s: WorldSignal) {
        signals.append(s)
        if signals.count > 128 {
            signals.removeFirst()
        }
        revision += 1
    }
    mutating func applySignals() {
        let pending = signals
        signals = []
        for s in pending {
            let h = habitat(s.location)
            let loc = habitats[h].id
            interactions += 1
            switch s.kind {
            case "visit":
                let old = habitats[h].disturbance
                habitats[h].disturbance = min(1, old + 0.85)
                habitats[h].activity = min(1, habitats[h].activity + 0.25)
                habitats[h].lastVisited = time
                habitats[h].stable = 0
                event("habitat", loc, "visit", String(old), String(habitats[h].disturbance), "disturbance")
            case "food":
                habitats[h].food = min(1, habitats[h].food + s.amount * 0.4)
                event("habitat", loc, "food", "", String(habitats[h].food), "food")
            case "chemical":
                habitats[h].chemical = min(1, habitats[h].chemical + s.amount)
                event(s.entity, loc, "spray", "", String(habitats[h].chemical), "chemical")
            case "clean":
                habitats[h].food = 0
                habitats[h].chemical = 0
                habitats[h].nest = false
                habitats[h].exposed = false
                event("habitat", loc, "clean", "nest/residue", "clear", "food")
            default: break
            }
            if let i = creatures.firstIndex(where: {
                $0.id == s.entity
            }) {
                if s.kind == "threat" {
                    creatures[i].threat = min(1, creatures[i].threat + 0.3)
                    creatures[i].fear = min(1, creatures[i].fear + 0.3)
                    event(s.entity, loc, "player threat", "", String(creatures[i].threat), "memory")
                }
                if s.kind == "friendly" {
                    creatures[i].friendly = min(1, creatures[i].friendly + 0.15)
                    creatures[i].hunger = max(0, creatures[i].hunger - 0.2)
                    event(s.entity, loc, "player friendly", "", String(creatures[i].friendly), "memory")
                }
            }
            if let i = creatures.firstIndex(where: {
                $0.id == s.entity
            }), !creatures[i].protected {
                if s.kind == "defeat" && creatures[i].roach {
                    event(s.entity, loc, "manual defeat", creatures[i].stage, "corpse", "player")
                    creatures[i].stage = "corpse"
                    deaths += 1
                }
                if s.kind == "remove" {
                    event(s.entity, loc, "vacuum", creatures[i].stage, "removed", "player")
                    creatures.remove(at: i)
                }
            }
            if s.kind == "chemical" {
                for i in creatures.indices where creatures[i].location == loc {
                    creatures[i].playerChemical = true
                    if creatures[i].id == s.entity {
                        creatures[i].distance = 0
                    }
                }
            }
        }
    }
    func preference(_ h: WorldHabitat, _ c: WorldCreature) -> Double {
        h.nestability * 0.6 + h.food * (0.4 + c.hunger) - h.disturbance * 1.4 - h.chemical * 2 - h.pressure * 0.4 + h
            .safety * 0.2 + (c.locationMemory == h.id ? 0.08 : 0)
    }
    func migrationAllowed(_ c: WorldCreature, _ h: WorldHabitat, _ destination: WorldHabitat) -> Bool {
        let advantage = preference(destination, c) - preference(h, c)
        if migrationMode == "control" {
            return time >= c.cooldown && destination.id != h.id && preference(destination, c) > preference(h, c) + 0.15
        }
        let strong = h.chemical > 0.6 || c.fear + c.threat > 0.9 || h.disturbance > 0.85 || h.pressure > 2
        let elapsed = c.lastMigrationTime < 0 ? 1e9 : time - c.lastMigrationTime
        let inertia = 0.12 * max(0, 1 - elapsed / 90)
        return destination.id != h.id
            && (strong ? advantage > 0.15 : time >= c.cooldown && elapsed >= 30 && advantage > 0.30 + inertia)
    }
    mutating func recordMigration(_ c: inout WorldCreature, to destination: String, chemical: Double) {
        if c.lastMigrationTime >= 0 && time - c.lastMigrationTime <= 120 && destination == c.previousLocation {
            reversals += 1
        }
        if chemical > 0.4 {
            chemicalMigrations += 1
        }
        c.previousLocation = c.location
        c.lastMigrationTime = time
    }
    mutating func step(rate: Double = 1, director: any IWorldDirector = RuleBasedWorldDirector()) {
        let dt = 2.0
        time += dt
        revision += 1
        visitorKind = ""
        applySignals()
        limitResidues()
        advanceResidues(dt)
        let d = director.parameters(self)
        visibleActivity *= 0.995
        // 1, 6, 8: disturbance / population pressure / game-only food signals.
        for h in habitats.indices {
            let n = creatures.filter {
                $0.roach && $0.location == habitats[h].id
            }.count
            habitats[h].pressure = Double(n) / 6
            habitats[h].disturbance = max(0, habitats[h].disturbance - dt / 120)
            habitats[h].activity = max(0, habitats[h].activity - dt / 1800)
            habitats[h].food = max(0, habitats[h].food - dt / 18000)
            habitats[h].chemical = max(0, habitats[h].chemical - dt / 480)
            habitats[h].stable =
                habitats[h].disturbance < 0.2 && habitats[h].chemical < 0.15 ? habitats[h].stable + dt : 0
            // 3: nests require sustained local suitability and resident population.
            if !habitats[h].nest && n >= 2 && habitats[h].stable > 60 && habitats[h].nestability > 0.5 {
                if random() < dt / 240 * min(2, Double(n) / 3) * d.pressure {
                    habitats[h].nest = true
                    event("nest", habitats[h].id, "formation", "absent", "nest", "nest")
                }
            }
        }
        let count = creatures.count
        for i in 0..<count {
            var c = creatures[i]
            guard c.roach || c.stage == "egg" else { continue }
            let hi = habitat(c.location)
            let h = habitats[hi]
            if c.stage == "egg" {
                c.age += dt * rate * (h.chemical > 0.4 ? 0.4 : 1)
                if c.age >= 180 && ecologicalCount < capacity - 1 {
                    c.stage = "hatched"
                    c.dormant = false
                    creatures[i] = c
                    event(c.id, h.id, "incubation", "egg", "hatched", "lifecycle")
                    for _ in 0..<2 {
                        let baby = add("baby", h.id)
                        if let j = creatures.firstIndex(where: {
                            $0.id == baby
                        }) {
                            creatures[j].originEgg = c.id
                        }
                    }
                }
                if c.stage == "egg" && c.age >= 180 {
                    c.age = 180
                    if !c.dormant {
                        event(c.id, h.id, "dormant", "egg", "dormant", "lifecycle")
                    }
                    c.dormant = true
                }
                creatures[i] = c
                continue
            }
            guard c.roach else {
                continue
            }
            c.age += dt * rate
            c.hunger = min(1, c.hunger + dt / 1200)
            c.fear = max(0, c.fear - dt / 240)
            c.threat = max(0, c.threat - dt / 7200)
            c.energy = max(0.1, c.energy - dt / 2400)
            if c.stage == "baby" && c.age >= 300 {
                c.stage = random() < 0.08 * d.rarity ? "gold" : "adult"
                c.age = 0
                event(c.id, h.id, "maturation", "baby", c.stage, "lifecycle")
            }
            // 5: dose depends on distance and resistance; eggs have a separate shell lifecycle.
            if !c.protected && h.safety < 0.5 {
                c.exposure = max(
                    0, c.exposure + h.chemical * (1 - c.distance * 0.8) * (1 - c.resistance * 0.75) * dt / 14 - dt / 300
                )
                if c.exposure >= 1 {
                    c.stage = "corpse"
                    deaths += 1
                    event(c.id, h.id, "dose", "alive", "corpse", "chemical")
                    creatures[i] = c
                    continue
                }
            }
            // 9: utility competition. Stable ordering resolves ties; no story IDs.
            let alarm = h.disturbance + c.fear + c.threat + h.chemical * (0.5 + c.resistance) + d.tension * 0.1
            let scores: [(String, Double)] = [
                ("flee", alarm * 1.4 - c.boldness * 1.5), ("hide", alarm * (1 - c.boldness) * 0.8 + 0.1),
                ("freeze", h.disturbance * c.boldness * 0.8), ("eat", c.hunger * h.food * 1.8),
                ("rest", (1 - c.energy) * 0.9), ("explore", c.curiosity * 0.3 + h.pressure * 0.32),
                ("approach", c.friendly * 0.7 + c.trust * 0.04 - c.threat),
                ("nest", h.nestability * 0.3 + (h.nest ? 0.15 : 0) - h.disturbance), ("idle", 0.18)
            ]
            let intent = scores.max {
                $0.1 < $1.1
            }!.0
            if c.intent != intent {
                event(c.id, h.id, "utility", c.intent, intent, "utility")
                c.intent = intent
            }
            // 2: migrate only when a better location exists and movement cooldown allows it.
            let destination = habitats.indices.max {
                preference(habitats[$0], c) < preference(habitats[$1], c)
            }!
            if migrationAllowed(c, h, habitats[destination]) && (intent == "flee" || random() < dt / 40) {
                recordMigration(&c, to: habitats[destination].id, chemical: h.chemical)
                let old = c.location
                c.emergedFrom = old
                c.location = habitats[destination].id
                c.home = c.location
                c.locationMemory = c.location
                c.cooldown = time + 20
                c.visibleUntil = time + 10
                migrations += 1
                visibleActivity += 1
                event(c.id, c.location, "migration", old, c.location, "preference")
                if h.nest && !habitats[hi].exposed {
                    habitats[hi].exposed = true
                    event("nest", h.id, "passing resident", "hidden", "exposed", "pressure")
                }
            } else if intent == "flee" || (intent == "explore" && random() < dt / 90)
                || (intent == "approach" && random() < dt / 60)
            {
                c.visibleUntil = time + 8
                visibleActivity += 0.2
            }
            if intent == "hide" || intent == "freeze" {
                c.visibleUntil = min(c.visibleUntil, time)
            }
            if intent == "eat" {
                c.hunger = max(0, c.hunger - dt / 15)
                c.energy = min(1, c.energy + dt / 60)
                habitats[hi].food = max(0, habitats[hi].food - dt / 500)
            }
            if intent == "rest" {
                c.energy = min(1, c.energy + dt / 120)
            }
            // 4: eggs require a fed fertile adult in a stable nest, capped by carrying capacity.
            if c.stage != "baby" && h.nest && h.stable > 60 && c.hunger < 0.8 && time >= c.cooldown
                && ecologicalCount < min(32, capacity - 2)
            {
                if random() < dt * rate / 600 * c.fertility * d.pressure {
                    _ = add("egg", h.id)
                    c.cooldown = time + 120
                    event(c.id, h.id, "fertility", "adult", "egg case", "lifecycle")
                }
            }
            creatures[i] = c
        }
        creatures.removeAll {
            $0.stage == "hatched"
        }
        limitResidues()
        // 10: rare visitors respond to ecology and interaction history; cooldown is not a playtime unlock.
        if interactions > 0 && visibleActivity > 0.5 {
            if time >= mouseCooldown && random() < dt / 900 * min(2, visibleActivity / 4) * d.rarity {
                visitorKind = "mouse"
                mouseCooldown = time + 180
            }
            if time >= catCooldown && random() < dt / 1800 * min(2, visibleActivity / 8) * d.rarity {
                visitorKind = "catPaw"
                catCooldown = time + 300
            }
            if !visitorKind.isEmpty {
                event(visitorKind, "edge", "ecosystem attraction", "absent", "visiting", "visitors")
                for j in creatures.indices where creatures[j].roach && !creatures[j].protected {
                    creatures[j].fear = min(1, creatures[j].fear + 0.3)
                }
            }
        }
    }
}

private struct WorldKey: CodingKey {
    var stringValue: String
    var intValue: Int? {
        nil
    }
    init(_ key: String) {
        stringValue = key
    }
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    init?(intValue: Int) {
        return nil
    }
}
extension WorldHabitat {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: WorldKey.self)
        id = try c.decodeIfPresent(String.self, forKey: WorldKey("id")) ?? id
        disturbance = try c.decodeIfPresent(Double.self, forKey: WorldKey("disturbance")) ?? disturbance
        activity = try c.decodeIfPresent(Double.self, forKey: WorldKey("activity")) ?? activity
        food = try c.decodeIfPresent(Double.self, forKey: WorldKey("food")) ?? food
        nestability = try c.decodeIfPresent(Double.self, forKey: WorldKey("nestability")) ?? nestability
        chemical = try c.decodeIfPresent(Double.self, forKey: WorldKey("chemical")) ?? chemical
        safety = try c.decodeIfPresent(Double.self, forKey: WorldKey("safety")) ?? safety
        pressure = try c.decodeIfPresent(Double.self, forKey: WorldKey("pressure")) ?? pressure
        lastVisited = try c.decodeIfPresent(Double.self, forKey: WorldKey("lastVisited")) ?? lastVisited
        stable = try c.decodeIfPresent(Double.self, forKey: WorldKey("stable")) ?? stable
        nest = try c.decodeIfPresent(Bool.self, forKey: WorldKey("nest")) ?? nest
        exposed = try c.decodeIfPresent(Bool.self, forKey: WorldKey("exposed")) ?? exposed
        discovered = try c.decodeIfPresent(Bool.self, forKey: WorldKey("discovered")) ?? discovered
    }
}
extension WorldCreature {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: WorldKey.self)
        residueAge = try c.decodeIfPresent(Double.self, forKey: WorldKey("residueAge")) ?? 0
        dormant = try c.decodeIfPresent(Bool.self, forKey: WorldKey("dormant")) ?? false
        lastMigrationTime =
            try c.decodeIfPresent(Double.self, forKey: WorldKey("lastMigrationTime")) ?? lastMigrationTime
        previousLocation = try c.decodeIfPresent(String.self, forKey: WorldKey("previousLocation")) ?? previousLocation
        originEgg = try c.decodeIfPresent(String.self, forKey: WorldKey("originEgg")) ?? originEgg
        id = try c.decodeIfPresent(String.self, forKey: WorldKey("id")) ?? id
        stage = try c.decodeIfPresent(String.self, forKey: WorldKey("stage")) ?? stage
        home = try c.decodeIfPresent(String.self, forKey: WorldKey("home")) ?? home
        location = try c.decodeIfPresent(String.self, forKey: WorldKey("location")) ?? location
        intent = try c.decodeIfPresent(String.self, forKey: WorldKey("intent")) ?? intent
        locationMemory = try c.decodeIfPresent(String.self, forKey: WorldKey("locationMemory")) ?? locationMemory
        age = try c.decodeIfPresent(Double.self, forKey: WorldKey("age")) ?? age
        energy = try c.decodeIfPresent(Double.self, forKey: WorldKey("energy")) ?? energy
        hunger = try c.decodeIfPresent(Double.self, forKey: WorldKey("hunger")) ?? hunger
        fear = try c.decodeIfPresent(Double.self, forKey: WorldKey("fear")) ?? fear
        curiosity = try c.decodeIfPresent(Double.self, forKey: WorldKey("curiosity")) ?? curiosity
        boldness = try c.decodeIfPresent(Double.self, forKey: WorldKey("boldness")) ?? boldness
        fertility = try c.decodeIfPresent(Double.self, forKey: WorldKey("fertility")) ?? fertility
        trust = try c.decodeIfPresent(Double.self, forKey: WorldKey("trust")) ?? trust
        threat = try c.decodeIfPresent(Double.self, forKey: WorldKey("threat")) ?? threat
        friendly = try c.decodeIfPresent(Double.self, forKey: WorldKey("friendly")) ?? friendly
        exposure = try c.decodeIfPresent(Double.self, forKey: WorldKey("exposure")) ?? exposure
        resistance = try c.decodeIfPresent(Double.self, forKey: WorldKey("resistance")) ?? resistance
        distance = try c.decodeIfPresent(Double.self, forKey: WorldKey("distance")) ?? distance
        cooldown = try c.decodeIfPresent(Double.self, forKey: WorldKey("cooldown")) ?? cooldown
        visibleUntil = try c.decodeIfPresent(Double.self, forKey: WorldKey("visibleUntil")) ?? visibleUntil
        emergedFrom = try c.decodeIfPresent(String.self, forKey: WorldKey("emergedFrom")) ?? emergedFrom
        protected = try c.decodeIfPresent(Bool.self, forKey: WorldKey("protected")) ?? protected
        playerChemical = try c.decodeIfPresent(Bool.self, forKey: WorldKey("playerChemical")) ?? playerChemical
    }
}
extension World {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: WorldKey.self)
        migrationMode = try c.decodeIfPresent(String.self, forKey: WorldKey("migrationMode")) ?? migrationMode
        reversals = try c.decodeIfPresent(Int.self, forKey: WorldKey("reversals")) ?? reversals
        chemicalMigrations =
            try c.decodeIfPresent(Int.self, forKey: WorldKey("chemicalMigrations")) ?? chemicalMigrations
        eventSerial = try c.decodeIfPresent(UInt64.self, forKey: WorldKey("eventSerial")) ?? eventSerial
        capacity = try c.decodeIfPresent(Int.self, forKey: WorldKey("capacity")) ?? capacity
        schema = try c.decodeIfPresent(Int.self, forKey: WorldKey("schema")) ?? schema
        revision = try c.decodeIfPresent(Int.self, forKey: WorldKey("revision")) ?? revision
        deaths = try c.decodeIfPresent(Int.self, forKey: WorldKey("deaths")) ?? deaths
        migrations = try c.decodeIfPresent(Int.self, forKey: WorldKey("migrations")) ?? migrations
        births = try c.decodeIfPresent(Int.self, forKey: WorldKey("births")) ?? births
        seed = try c.decodeIfPresent(UInt64.self, forKey: WorldKey("seed")) ?? seed
        rng = try c.decodeIfPresent(UInt64.self, forKey: WorldKey("rng")) ?? seed
        serial = try c.decodeIfPresent(UInt64.self, forKey: WorldKey("serial")) ?? serial
        time = try c.decodeIfPresent(Double.self, forKey: WorldKey("time")) ?? time
        interactions = try c.decodeIfPresent(Double.self, forKey: WorldKey("interactions")) ?? interactions
        visibleActivity = try c.decodeIfPresent(Double.self, forKey: WorldKey("visibleActivity")) ?? visibleActivity
        mouseCooldown = try c.decodeIfPresent(Double.self, forKey: WorldKey("mouseCooldown")) ?? mouseCooldown
        catCooldown = try c.decodeIfPresent(Double.self, forKey: WorldKey("catCooldown")) ?? catCooldown
        visitorKind = try c.decodeIfPresent(String.self, forKey: WorldKey("visitorKind")) ?? visitorKind
        habitats = try c.decodeIfPresent([WorldHabitat].self, forKey: WorldKey("habitats")) ?? habitats
        creatures = try c.decodeIfPresent([WorldCreature].self, forKey: WorldKey("creatures")) ?? creatures
        signals = try c.decodeIfPresent([WorldSignal].self, forKey: WorldKey("signals")) ?? signals
        recentEvents = try c.decodeIfPresent([WorldEvent].self, forKey: WorldKey("recentEvents")) ?? recentEvents
    }
}
