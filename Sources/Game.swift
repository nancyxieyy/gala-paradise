import Foundation

enum Tool: String, Codable, CaseIterable {
    case pinch, slipper, poison, vacuum, cleaner
    var title: String {
        switch self {
        case .pinch: return "捏一下"
        case .slipper: return "人字拖"
        case .poison: return "蟑螂药"
        case .vacuum: return "吸尘器"
        case .cleaner: return "清洁剂"
        }
    }
    var glyph: String {
        switch self {
        case .pinch: return "hand.point.up.left.fill"
        case .slipper: return "shoe.fill"
        case .poison: return "cross.vial.fill"
        case .vacuum: return "wind"
        case .cleaner: return "sparkles"
        }
    }
    var threshold: Int {
        switch self {
        case .pinch: return 0
        case .slipper: return 5
        case .poison: return 12
        case .vacuum: return 20
        case .cleaner: return 28
        }
    }
    var detail: String {
        switch self {
        case .pinch: return "一捏爆浆，留下奶油污渍"
        case .slipper: return "啪！留下翻肚皮的小家伙"
        case .poison: return "留下药剂，影响经过的旮杂"
        case .vacuum: return "吸走小旮杂、尸体和角落的卵"
        case .cleaner: return "擦掉爆浆，桌面终于干净了？"
        }
    }
}
enum BugKind: String, Codable {
    case adult, baby, egg, corpse, stain, gold, mouse, catPaw
}
struct Resident: Codable, Identifiable {
    var id = UUID()
    var kind: BugKind
    var x: Double
    var y: Double
    var born: Double
    var vx: Double = 0
    var vy: Double = 0
    var flyingUntil: Double = 0
    var ecologyIntent: String?
    var holdUntil: Double?
    var reactionUntil: Double?
    var carryUntil: Double?
    var tauntUntil: Double = 0
    var friend: Bool {
        kind == .mouse || kind == .catPaw
    }
    var live: Bool {
        kind == .adult || kind == .baby || kind == .gold || friend
    }
}
struct GameState: Codable {
    var world: World?
    var life: Life? = Life()
    var progression: Progression? = Progression()
    var version = 1
    var xp = 0
    var captures = 0
    var cleaned = 0
    var foldersOpened = 0
    var fed = 0
    var tool: Tool = .pinch
    var poisoned = false
    var quiet = false
    var residents: [Resident] = []
    var lastSaved = Date().timeIntervalSince1970
    var unlocked: [Tool] {
        progression?.owned
            ?? Tool.allCases.filter {
                xp >= $0.threshold
            }
    }
    var level: Int {
        min(5, xp / 10 + 1)
    }
    mutating func gain(_ amount: Int) {
        xp += amount
    }
    mutating func use(_ tool: Tool, on id: UUID, now: Double, flightRoll: Double) -> String {
        guard unlocked.contains(tool) else {
            return "还没解锁，先喂食或捉几只旮杂"
        }
        guard
            let i = residents.firstIndex(where: {
                $0.id == id
            })
        else {
            return ""
        }
        ensureLife()
        let kind = residents[i].kind
        defer {
            reconcileWorld()
        }
        if tool == .poison && residents[i].live && !residents[i].friend && !protected(residents[i]) {
            worldSignal("threat", id: id)
            worldSignal("chemical", id: id)
            return "呲——"
        }
        if residents[i].live {
            worldSignal(
                tool == .pinch && (residents[i].friend || protected(residents[i])) ? "friendly" : "threat", id: id)
        }
        if protected(residents[i]) || residents[i].friend {
            return playfulUse(tool, on: id, now: now)
        }
        if residents[i].live {
            if tool == .cleaner {
                return "清洁剂只擦污渍，旮杂笑你了"
            }

            if residents[i].flyingUntil > now && tool != .vacuum {
                return "嘿嘿，打不到～等它落地，或用吸尘器"
            }
            if (kind == .adult || kind == .gold) && tool != .vacuum && tool != .poison && flightRoll < 0.24 {
                life!.observe(residents[i], now)
                life!.bonds[id.uuidString.lowercased()]!.fear += 1
                residents[i].flyingUntil = now + 2.8
                residents[i].tauntUntil = now + 2.8
                return "它居然起飞了！打不到～"
            }
            if kind == .gold {
                migrateProgression()
                progression!.shells += life!.gold(id, now)
            }
            captures += 1
            gain(2)
            if tool == .vacuum {
                residents.remove(at: i)
                return "咻——吸走一只旮杂"
            }
            life!.defeat(now)
            residents[i].kind = tool == .pinch ? .stain : .corpse
            residents[i].born = now
            return tool == .pinch ? "噗叽！奶油爆浆留下了，得用清洁剂擦" : "啪！已躺平。吸尘器负责收尾"
        }
        if kind == .stain && tool == .cleaner {
            residents.remove(at: i)
            cleaned += 1
            gain(2)
            return "擦得亮晶晶。角落里呢？"
        }
        if (kind == .egg || kind == .corpse) && tool == .vacuum {
            residents.remove(at: i)
            cleaned += 1
            gain(2)
            return kind == .egg ? "吸掉一窝卵，少了一群后患" : "尸体收走啦"
        }
        return kind == .stain ? "这是顽固污渍，要用清洁剂" : "用吸尘器把它收走吧"
    }
}

func runModelTests() {
    var g = GameState()
    g.progression = nil
    precondition(g.unlocked == [.pinch])
    let r = Resident(kind: .adult, x: 100, y: 100, born: 0)
    g.residents = [r]
    _ = g.use(.slipper, on: r.id, now: 10, flightRoll: 1)
    precondition(g.residents[0].kind == .adult && g.xp == 0)
    _ = g.use(.pinch, on: r.id, now: 10, flightRoll: 0)
    precondition(g.residents[0].flyingUntil == 12.8 && g.captures == 0)
    _ = g.use(.pinch, on: r.id, now: 11, flightRoll: 1)
    precondition(g.captures == 0)
    _ = g.use(.pinch, on: r.id, now: 14, flightRoll: 1)
    precondition(g.residents[0].kind == .stain && g.captures == 1 && g.xp == 2)
    g.xp = 28
    _ = g.use(.vacuum, on: r.id, now: 20, flightRoll: 1)
    precondition(g.residents.count == 1)
    _ = g.use(.cleaner, on: r.id, now: 20, flightRoll: 1)
    precondition(g.residents.isEmpty && g.cleaned == 1)
    for kind in [BugKind.egg, .corpse, .adult, .baby] {
        var r = Resident(kind: kind, x: 0, y: 0, born: 0)
        r.flyingUntil = 100
        g.residents = [r]
        _ = g.use(.vacuum, on: r.id, now: 20, flightRoll: 0)
        precondition(g.residents.isEmpty)
    }
    precondition(g.unlocked.count == 5)
    let live = Resident(kind: .adult, x: 3, y: 4, born: 2)
    g.residents = [live]
    _ = g.use(.slipper, on: live.id, now: 20, flightRoll: 1)
    precondition(g.residents[0].kind == .corpse)
    g.residents = [Resident(kind: .baby, x: 1, y: 2, born: 0)]
    _ = g.use(.pinch, on: g.residents[0].id, now: 10, flightRoll: 0)
    precondition(g.residents[0].kind == .stain)
    g.residents = [live]
    _ = g.use(.poison, on: live.id, now: 20, flightRoll: 0)
    precondition(
        g.residents[0].kind == .adult
            && g.world!.signals.contains {
                $0.kind == "chemical"
            })
    g.residents = [live]
    _ = g.use(.cleaner, on: live.id, now: 20, flightRoll: 1)
    precondition(g.residents[0].kind == .adult)
    g.residents += [Resident(kind: .egg, x: 70, y: 50, born: 9), Resident(kind: .stain, x: 10, y: 30, born: 4)]
    g.poisoned = true
    g.quiet = true
    let data = try! JSONEncoder().encode(g)
    let restored = try! JSONDecoder().decode(GameState.self, from: data)
    precondition(restored.xp == g.xp && restored.captures == g.captures)
    precondition(
        restored.residents.count == 3 && restored.residents[2].kind == .stain && restored.poisoned && restored.quiet)
    print("PASS: tool locks, flying/landing, pinch stain, cleanup compatibility, vacuum, progression, save round-trip")
}

extension GameState {
    mutating func playfulUse(_ tool: Tool, on id: UUID, now: Double) -> String {
        guard
            let i = residents.firstIndex(where: {
                $0.id == id
            })
        else {
            return ""
        }
        ensureLife()
        let r = residents[i]
        residents[i].holdUntil = now + 1.5
        residents[i].reactionUntil = now + 0.55
        if r.kind == .catPaw {
            residents[i].born = now - 2
        }
        if tool == .pinch {
            _ = life!.interact(r, action: "pet", text: "", now: now)
        }
        switch tool {
        case .pinch: return r.kind == .catPaw ? "呼噜～再摸一下 ♡" : "蹭蹭你的手 ♡"
        case .slipper: return r.kind == .catPaw ? "啪！猫爪接住了拖鞋" : "嗖！侧身躲开，还回头看你"
        case .poison: return "阿嚏！抖掉泡沫，瞪你一眼"
        case .vacuum: return r.kind == .catPaw ? "爪子按住吸嘴：不许吸！" : "呼——毛都吹乱啦！"
        case .cleaner: return "擦擦脸，亮晶晶 ✦"
        }
    }
}
