import Foundation
struct Progression: Codable {
    var shells = 0
    var owned: [Tool] = [.pinch]
    var played: Double = 0
    var seen: [String] = []
}
extension Tool {
    var cost: Int {
        switch self {
        case .pinch: return 0
        case .slipper: return 2
        case .poison: return 4
        case .vacuum: return 6
        case .cleaner: return 5
        }
    }
}
extension GameState {
    mutating func migrateProgression() {
        if progression == nil {
            var p = Progression()
            p.owned = Tool.allCases.filter {
                xp >= $0.threshold
            }
            progression = p
        }
        if !unlocked.contains(tool) {
            tool = .pinch
            poisoned = false
        }
    }
    mutating func redeem(_ t: Tool) -> Bool {
        migrateProgression()
        if unlocked.contains(t) {
            return true
        }
        guard progression!.shells >= t.cost else {
            return false
        }
        progression!.shells -= t.cost
        progression!.owned.append(t)
        return true
    }
}
func runProgressionTests() {
    var g = GameState()
    g.xp = 100
    precondition(g.unlocked == [.pinch])
    g.progression!.shells = 4
    precondition(g.redeem(.poison))
    precondition(g.progression!.shells == 0)
    precondition(g.redeem(.poison) && g.progression!.shells == 0)
    precondition(!g.redeem(.vacuum))
    let r = Resident(kind: .gold, x: 0, y: 0, born: 0)
    g.residents = [r]
    _ = g.use(.pinch, on: r.id, now: 10, flightRoll: 1)
    precondition(g.progression!.shells == 2)
    _ = g.use(.pinch, on: r.id, now: 11, flightRoll: 1)
    precondition(g.progression!.shells == 2)
    let m = Resident(kind: .mouse, x: 0, y: 0, born: 0)
    g.residents = [m]
    _ = g.use(.pinch, on: m.id, now: 10, flightRoll: 1)
    precondition(g.residents[0].kind == .mouse)
    var old = GameState()
    old.xp = 20
    old.progression = nil
    let legacy = try! JSONEncoder().encode(old)
    old = try! JSONDecoder().decode(GameState.self, from: legacy)
    old.migrateProgression()
    precondition(old.unlocked.contains(.vacuum))
    let data = try! JSONEncoder().encode(g)
    let copy = try! JSONDecoder().decode(GameState.self, from: data)
    precondition(copy.progression!.shells == 2)
    print("PASS: shell economy, single reward, idempotent purchase, friend safety, legacy unlock migration")
}
