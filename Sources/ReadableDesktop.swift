import AppKit

// Presentation only. No World mutation and no random ecological decisions.
struct MigrationViewState {
    var destination: String
    var departedAt: Double?
}
final class HabitatCueView: NSView {
    var chemical = 0.0, crumbs = 0.0, shell = false
    override var isFlipped: Bool {
        true
    }
    override func draw(_ dirtyRect: NSRect) {
        if shell {
            drawBug(in: NSRect(x: 34, y: 0, width: 52, height: 52), kind: .egg, eggProgress: 1, emptyShell: true)
            return
        }
        for n in 0..<7 where chemical > 0 {
            oval(
                NSRect(x: 12 + n * 13, y: 18 + (n % 3) * 7, width: 20, height: 8), color(0xE4EFD9, chemical * 0.36),
                stroke: color(0xA6BA99, chemical * 0.2), width: 1)
        }
        for n in 0..<Int(crumbs * 8) {
            oval(NSRect(x: 19 + n * 11, y: 38 + (n % 3) * 4, width: 3 + n % 2, height: 2), color(0xA7814C, 0.55))
        }
    }
}
extension Paradise {
    func habitatAnchor(_ location: String) -> CGPoint {
        if let point = habitatAnchors[location] {
            return point
        }
        let f = NSScreen.main!.visibleFrame
        let index =
            state.world?.habitats.firstIndex {
                $0.id == location
            } ?? 0
        let point: CGPoint
        if let frame = folderFrames[location] {
            point = CGPoint(x: frame.minX - 50, y: frame.minY + 20)
        } else {
            point = CGPoint(
                x: index % 2 == 0 ? f.minX + 4 : f.maxX - 150, y: f.minY + 20 + Double((index / 2) % 5) * 72)
        }
        habitatAnchors[location] = point
        return point
    }
    func cuePanel(_ key: String, at p: CGPoint) -> PetPanel {
        if let panel = habitatCues[key] {
            panel.setFrameOrigin(p)
            return panel
        }
        let panel = PetPanel(
            contentRect: NSRect(x: p.x, y: p.y, width: 130, height: 60), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = HabitatCueView(frame: NSRect(x: 0, y: 0, width: 130, height: 60))
        habitatCues[key] = panel
        return panel
    }
    func projectReadable(_ before: [Resident], now: Double) {
        guard let w = state.world else {
            return
        }
        let prior = Dictionary(
            uniqueKeysWithValues: before.map {
                ($0.id, $0)
            })
        let events = w.recentEvents.filter {
            ($0.sequence ?? 0) > lastProjectedSequence
        }
        lastProjectedSequence = w.eventSerial
        for event in events where event.trigger == "incubation" {
            if let id = UUID(uuidString: event.entity), let egg = prior[id] {
                shellExpiry[event.entity] = w.time + 12
                let p = cuePanel("shell:" + event.entity, at: CGPoint(x: egg.x + 13, y: egg.y))
                (p.contentView as? HabitatCueView)?.shell = true
            }
        }
        for i in state.residents.indices {
            let r = state.residents[i]
            guard
                let c = w.creatures.first(where: {
                    $0.id == r.id.uuidString.lowercased()
                })
            else {
                continue
            }
            panels[r.id]?.alphaValue = c.stage == "corpse"
                ? 1 - 0.65 * min(1, c.residueAge / World.corpseDecay) : 1
            panels[r.id]?.contentView?.needsDisplay = true
            eggProgress[r.id] = c.stage == "egg" ? min(1, c.age / 180) : nil
            if prior[r.id] == nil {
                let origin = UUID(uuidString: c.originEgg).flatMap {
                    prior[$0]
                }
                let p =
                    origin.map {
                        CGPoint(x: $0.x, y: $0.y)
                    } ?? habitatAnchor(c.location)
                state.residents[i].x = p.x
                state.residents[i].y = p.y
                if c.stage == "egg" {
                    let offset =
                        Double(
                            w.creatures.filter {
                                $0.stage == "egg" && $0.location == c.location
                            }.firstIndex {
                                $0.id == c.id
                            } ?? 0) * 20
                    state.residents[i].x += offset
                }
                if c.stage == "baby", origin != nil {
                    let direction =
                        w.creatures.firstIndex {
                            $0.id == c.id
                        }!.isMultiple(of: 2) ? 1.0 : -1.0
                    visits[r.id] = Visit(
                        hidden: false, exiting: false, deadline: now + 6,
                        target: CGPoint(x: p.x + direction * 100, y: p.y + 30), screen: NSScreen.main!.frame)
                }
            }
        }
        for e in events where e.trigger == "migration" {
            guard let id = UUID(uuidString: e.entity),
                let r = state.residents.first(where: {
                    $0.id == id && $0.live
                })
            else {
                continue
            }
            // A second real decision during travel updates the destination, never teleports the sprite.
            if migrationViews[id] != nil {
                migrationViews[id]?.destination = e.new
                continue
            }
            if visits[id]?.hidden != false && visibleLiveCount < 3 {
                let p = habitatAnchor(e.previous)
                beginVisit(id, now: now, from: p)
            }
            if visits[id]?.hidden == false {
                let current = state.residents.first {
                    $0.id == id
                }!
                let f = visits[id]!.screen
                let dest = habitatAnchor(e.new)
                let target = CGPoint(x: dest.x >= current.x ? f.maxX : f.minX - petCanvas(r.kind).width, y: current.y)
                visits[id]?.exiting = true
                visits[id]?.target = target
                migrationViews[id] = MigrationViewState(destination: e.new)
            } else {
                migrationViews[id] = MigrationViewState(destination: e.new, departedAt: w.time)
            }
        }
        for id in Array(migrationViews.keys) {
            guard
                state.residents.contains(where: {
                    $0.id == id && $0.live
                })
            else {
                migrationViews.removeValue(forKey: id)
                continue
            }
            if visits[id]?.hidden != false {
                if migrationViews[id]!.departedAt == nil {
                    migrationViews[id]!.departedAt = w.time
                } else if w.time - migrationViews[id]!.departedAt! >= 4 && visibleLiveCount < 3 {
                    let destination = migrationViews[id]!.destination
                    let p = habitatAnchor(destination)
                    beginVisit(id, now: now, from: p)
                    visits[id]?.target = CGPoint(x: p.x + (p.x < NSScreen.main!.frame.midX ? 130 : -130), y: p.y + 25)
                    migrationViews.removeValue(forKey: id)
                }
            }
        }
        for (id, until) in shellExpiry where w.time >= until {
            habitatCues.removeValue(forKey: "shell:" + id)?.close()
            shellExpiry.removeValue(forKey: id)
        }
        var keep = Set(
            shellExpiry.keys.map {
                "shell:" + $0
            })
        for h in w.habitats.sorted(by: {
            $0.chemical + ($0.nest ? 1 : 0) + $0.activity > $1.chemical + ($1.nest ? 1 : 0) + $1.activity
        }).prefix(8) {
            let population = w.creatures.filter {
                $0.roach && $0.location == h.id
            }.count
            let crumbs = h.nest ? 0.9 : min(0.65, h.stable / 120) * min(1, Double(population) / 3) + h.activity * 0.15
            guard h.chemical > 0 || crumbs > 0.12 else {
                continue
            }
            let key = "habitat:" + h.id
            keep.insert(key)
            let panel = cuePanel(key, at: habitatAnchor(h.id))
            let view = panel.contentView as! HabitatCueView
            view.chemical = h.chemical
            view.crumbs = crumbs
            view.needsDisplay = true
        }
        for key in Array(habitatCues.keys) where !keep.contains(key) {
            habitatCues.removeValue(forKey: key)?.close()
        }
        syncReadableVisibility()
    }
    func syncReadableVisibility() {
        for panel in habitatCues.values {
            if paused || state.focusing || state.quiet {
                if panel.isVisible {
                    panel.orderOut(nil)
                }
            } else if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }
}
extension Paradise {
    func readableIntegrationTest() {
        let now = Date().timeIntervalSince1970
        state = GameState()
        state.progression!.owned = Tool.allCases
        habitat.rate = 1
        migrationViews.removeAll()
        habitatAnchors.removeAll()
        lastProjectedSequence = 0
        var w = World(seed: 42)
        w.habitats = [WorldHabitat(id: "A", chemical: 0.9), WorldHabitat(id: "B")]
        let key = w.add("adult", "A", record: false)
        w.creatures[0].boldness = 0
        let id = UUID(uuidString: key)!
        state.world = w
        state.residents = [Resident(id: id, kind: .adult, x: 220, y: 180, born: now)]
        visits[id] = Visit(
            hidden: false, deadline: now + 50, target: CGPoint(x: 500, y: 180), screen: NSScreen.main!.frame)
        ecology(now)
        precondition(state.world!.migrations == 1 && migrationViews[id] != nil && visits[id]!.exiting)
        precondition(
            state.residents[0].x == 220 && state.residents[0].y == 180,
            "Migration decision cannot teleport a visible resident")
        precondition((habitatCues["habitat:A"]?.contentView as? HabitatCueView)?.chemical ?? 0 > 0.8)
        let target = visits[id]!.target
        advanceVisits(now + 1, 0.1)
        precondition(visits[id]!.target == target, "Departure keeps one direction")
        // Complete actual interpolation, then verify a hidden transit interval before arrival.
        for tick in 1...1600 where visits[id]?.hidden == false {
            advanceVisits(now + Double(tick) / 30, 1.0 / 30)
        }
        precondition(visits[id]!.hidden)
        ecology(now + 60)
        precondition(visits[id]!.hidden)
        ecology(now + 62)
        precondition(visits[id]!.hidden)
        ecology(now + 64)
        precondition(visits[id]?.hidden == false && migrationViews[id] == nil)
        togglePause()
        precondition(
            habitatCues.values.allSatisfy {
                !$0.isVisible
            })
        togglePause()
        state = GameState()
        migrationViews.removeAll()
        lastProjectedSequence = 0
        w = World(seed: 9)
        w.habitats = [WorldHabitat(id: "A")]
        let egg = w.add("egg", "A", record: false)
        w.creatures[0].age = 178
        state.world = w
        let eggID = UUID(uuidString: egg)!
        state.residents = [Resident(id: eggID, kind: .egg, x: 340, y: 160, born: now)]
        ecology(now + 70)
        precondition(
            state.residents.count == 2
                && state.residents.allSatisfy {
                    $0.kind == .baby && $0.x == 340 && $0.y == 160
                })
        precondition(
            state.world!.creatures.allSatisfy {
                $0.originEgg == egg
            })
        precondition(habitatCues["shell:" + egg] != nil, "Only an actual hatch leaves an empty shell")
        // Render real lifecycle states using the native drawing path, for visual review.
        let image = NSImage(size: NSSize(width: 680, height: 190))
        image.lockFocusFlipped(true)
        paintRect(NSRect(x: 0, y: 0, width: 680, height: 190), cream)
        for (n, progress) in [0.0, 0.5, 0.95, 1.0].enumerated() {
            drawBug(
                in: NSRect(x: Double(n) * 165 + 20, y: 10, width: 120, height: 120), kind: .egg, eggProgress: progress,
                emptyShell: n == 3)
            drawBug(
                in: NSRect(x: Double(n) * 165 + 50, y: 130, width: 52, height: 52), kind: .egg, eggProgress: progress,
                emptyShell: n == 3)
        }
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
            try? bitmap.representation(using: .png, properties: [:])?.write(
                to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(
                    "Resources/readable-eggs.png"))
        }
        print(
            "PASS: native residue, stable migration departure, hidden transit, delayed arrival, hatch position/lineage, empty shell, pause cue suppression, egg rendering"
        )
    }
}
