import Foundation
struct InitialCreature: Decodable {
    var id: String?
    var stage: String?
    var location: String?
    var boldness: Double?
    var cooldown: Double?
    var age: Double?
    var protection: Bool?
}
struct InputAction: Decodable {
    var at: Int
    var every: Int?
    var kind: String
    var location: String?
    var entity: String?
    var amount: Double?
}
struct Scenario: Decodable {
    var name: String
    var migrationMode: String?
    var seed: UInt64
    var duration: Int
    var rate: Double?
    var removeCorpsesEvery: Int?
    var initial: World?
    var habitats: [WorldHabitat]
    var creatures: [InitialCreature]
    var actions: [InputAction]
}
struct CapacityObservation: Encodable {
    var firstTime: Double
    var lastTime: Double
    // total, living, eggs, mature eggs, corpses, stains, nests
    var counts: [Int]
}
struct CapacityEvidence: Encodable {
    var firstAt32 = -1.0
    var matureEggSeconds = 0.0
    var matureEggWallSeconds = 0.0
    var observations: [CapacityObservation] = []

    mutating func observe(_ world: World, dt: Double) {
        let mature = world.creatures.filter { $0.stage == "egg" && $0.age >= 180 }.count
        let counts = [
            world.creatures.count,
            world.creatures.filter { $0.roach }.count,
            world.creatures.filter { $0.stage == "egg" }.count,
            mature,
            world.creatures.filter { $0.stage == "corpse" }.count,
            world.creatures.filter { $0.stage == "stain" }.count,
            world.habitats.filter { $0.nest }.count
        ]
        if firstAt32 < 0 && counts[0] >= 32 {
            firstAt32 = world.time
        }
        matureEggSeconds += Double(mature) * dt
        if mature > 0 {
            matureEggWallSeconds += dt
        }
        if observations.last?.counts == counts {
            observations[observations.count - 1].lastTime = world.time
        } else {
            observations.append(CapacityObservation(firstTime: world.time, lastTime: world.time, counts: counts))
        }
    }
}
let input = try JSONDecoder().decode(
    Scenario.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var w = input.initial ?? World(seed: input.seed)
if input.initial == nil {
    w.migrationMode = input.migrationMode ?? "treatment"
    w.habitats = input.habitats
    for c in input.creatures {
        let id = w.add(c.stage ?? "adult", c.location ?? "edge", id: c.id, record: false)
        let i = w.creatures.firstIndex {
            $0.id == id
        }!
        if let b = c.boldness {
            w.creatures[i].boldness = b
        }
        if let cooldown = c.cooldown {
            w.creatures[i].cooldown = cooldown
        }
        w.creatures[i].age = c.age ?? 0
        w.creatures[i].protected = c.protection ?? false
    }
}
var events: [WorldEvent] = []
var samples: [[String: Double]] = []
var capacityEvidence = CapacityEvidence()
capacityEvidence.observe(w, dt: 0)
let removalInterval = input.removeCorpsesEvery ?? 0
var nextCorpseRemoval = removalInterval > 0 ? removalInterval : Int.max
let start = Date()
for t in stride(from: 0, to: input.duration, by: 2) {
    if removalInterval > 0 && t >= nextCorpseRemoval {
        for c in w.creatures where c.stage == "corpse" {
            w.send(WorldSignal(kind: "remove", location: c.location, entity: c.id))
        }
        nextCorpseRemoval += ((t - nextCorpseRemoval) / removalInterval + 1) * removalInterval
    }
    for a in input.actions where t >= a.at && ((a.every ?? 0) > 0 ? (t - a.at) % a.every! == 0 : t == a.at) {
        w.send(WorldSignal(kind: a.kind, location: a.location ?? "edge", entity: a.entity ?? "", amount: a.amount ?? 1))
    }
    w.recentEvents = []
    w.step(rate: input.rate ?? 1)
    capacityEvidence.observe(w, dt: 2)
    events += w.recentEvents
    if t % 60 == 0 {
        samples.append([
            "eggAge": w.creatures.filter {
                $0.stage == "egg"
            }.map {
                $0.age
            }.max() ?? 0,
            "juveniles": Double(
                w.creatures.filter {
                    $0.stage == "baby"
                }.count), "time": w.time,
            "population": Double(
                w.creatures.filter {
                    $0.roach
                }.count),
            "eggs": Double(
                w.creatures.filter {
                    $0.stage == "egg"
                }.count),
            "nests": Double(
                w.habitats.filter {
                    $0.nest
                }.count), "deaths": Double(w.deaths),
            "migrations": Double(w.migrations)
        ])
    }
}
struct Output: Encodable {
    var world: World
    var eventLog: [WorldEvent]
    var samples: [[String: Double]]
    var metrics: [String: Double]
    var unexpectedInteractions: [WorldEvent]
    var capacityEvidence: CapacityEvidence
}
let metrics = [
    "population": Double(
        w.creatures.filter {
            $0.roach
        }.count),
    "eggs": Double(
        w.creatures.filter {
            $0.stage == "egg"
        }.count),
    "nests": Double(
        w.habitats.filter {
            $0.nest
        }.count), "deaths": Double(w.deaths),
    "migrations": Double(w.migrations), "births": Double(w.births), "elapsedMs": Date().timeIntervalSince(start) * 1000
]
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(
    Output(
        world: w, eventLog: events, samples: samples, metrics: metrics,
        unexpectedInteractions: events.filter {
            ["migration", "formation", "passing resident"].contains($0.trigger)
        }, capacityEvidence: capacityEvidence)
).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("\(input.name): \(metrics)")
