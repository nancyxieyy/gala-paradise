import AppKit
final class LifeView: NSView {
    override var isFlipped: Bool {
        true
    }
    override func draw(_ dirtyRect: NSRect) {
        cream.setFill()
        bounds.fill()
    }
}
final class LifeCardsView: NSView {
    var life = Life()
    var message = ""
    override var isFlipped: Bool {
        true
    }
    override func draw(_ dirtyRect: NSRect) {
        cream.setFill()
        bounds.fill()
        label(message, 10, 8, size: 12, width: bounds.width - 20)
        label(
            "脚印：" + (life.traceReady ? "发现碎屑，可追踪" : "等待新的痕迹") + " · 安全窝：" + (life.safeLeft ? "开启" : "关闭") + " · 专注剩余 "
                + String(Int(life.focusRemaining)) + " 秒", 10, 48, size: 12, width: bounds.width - 20)
        for (i, a) in Life.achievements.enumerated() {
            let column = bounds.width / 2
            let x = CGFloat(i % 2) * column + 5, y = CGFloat(i / 2) * 79 + 83
            let earned = life.cards[a.0]
            paintRect(
                NSRect(x: x, y: y, width: column - 10, height: 69), earned == nil ? color(0xECEBDF) : color(0xDDE6CD),
                radius: 12)
            label((earned == nil ? "○ " : "✦ ") + a.1, x + 12, y + 10, size: 14, weight: .semibold, width: column - 34)
            label(
                earned.map {
                    Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .shortened)
                }
                    ?? "尚未发现 · 不必集齐每条支线", x + 12, y + 39, size: 11, width: column - 34)
        }
    }
}

final class CompanionPreview: NSView {
    var kind: BugKind = .adult {
        didSet {
            needsDisplay = true
        }
    }
    override var isFlipped: Bool {
        true
    }
    override func draw(_ rect: NSRect) {
        drawBug(in: bounds.insetBy(dx: 5, dy: 5), kind: kind, phase: kind == .catPaw ? 3 : 0)
    }
}
final class LifeController: NSWindowController {
    weak var engine: Paradise?
    let guests = NSPopUpButton()
    let input = NSTextField()
    let notes = NSPopUpButton()
    let minutes = NSTextField(string: "25")
    let report = NSTextView()
    let cards = LifeCardsView()
    var tabs: NSSegmentedControl!
    var panes: [NSView] = []
    var portrait: CompanionPreview!
    let focusStatus = NSTextField(labelWithString: "")
    let feedback = NSTextField(labelWithString: "")
    var ids: [UUID] = []
    var noteIDs: [String] = []
    init(_ engine: Paradise) {
        self.engine = engine
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 450), styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        super.init(window: w)
        w.title = "我的小窝"
        w.isReleasedWhenClosed = false
        w.backgroundColor = cream
        let v = LifeView(frame: NSRect(x: 0, y: 0, width: 620, height: 450))
        w.contentView = v
        tabs = NSSegmentedControl(
            labels: ["伙伴", "纸条", "专注", "成就"], trackingMode: .selectOne, target: self, action: #selector(tabChanged))
        tabs.frame = NSRect(x: 24, y: 22, width: 572, height: 32)
        tabs.selectedSegment = 0
        v.addSubview(tabs)
        for _ in 0..<4 {
            let pane = LifeView(frame: NSRect(x: 24, y: 76, width: 572, height: 330))
            v.addSubview(pane)
            panes.append(pane)
        }
        func title(_ text: String, _ y: CGFloat, _ pane: Int) {
            let t = NSTextField(labelWithString: text)
            t.frame = NSRect(x: 0, y: y, width: 560, height: 30)
            t.font = .systemFont(ofSize: 16, weight: .semibold)
            panes[pane].addSubview(t)
        }
        func button(
            _ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ pane: Int, _ action: @escaping () -> Void
        ) {
            panes[pane].addSubview(
                ActionButton(text, frame: NSRect(x: x, y: y, width: width, height: 38), action: action))
        }
        title("熟悉的身影", 0, 0)
        guests.frame = NSRect(x: 0, y: 42, width: 360, height: 30)
        panes[0].addSubview(guests)
        guests.target = self
        guests.action = #selector(guestChanged)
        portrait = CompanionPreview(frame: NSRect(x: 382, y: 30, width: 165, height: 165))
        panes[0].addSubview(portrait)
        title("叫它出来，在身上右键交朋友。", 94, 0)
        button("出来玩", 0, 137, 144, 0) {
            [weak self] in self?.perform("recall")
        }
        button("分享这位朋友", 154, 137, 176, 0) {
            [weak self] in self?.perform("share")
        }
        title("给大家留个位置", 220, 0)
        button("开关安全窝", 0, 264, 172, 0) {
            [weak self] in self?.perform("safe")
        }
        button("安排共居", 182, 264, 172, 0) {
            [weak self] in self?.perform("coexist")
        }
        button("接朋友入住…", 364, 264, 184, 0) {
            [weak self] in self?.importFriend()
        }
        title("交给它，替你收着。", 0, 1)
        input.frame = NSRect(x: 0, y: 42, width: 572, height: 32)
        input.placeholderString = "写一条待办，或粘贴一个链接"
        panes[1].addSubview(input)
        button("收好", 0, 88, 112, 1) {
            [weak self] in self?.perform("stash")
        }
        notes.frame = NSRect(x: 0, y: 151, width: 572, height: 30)
        panes[1].addSubview(notes)
        button("取回", 0, 198, 120, 1) {
            [weak self] in self?.perform("return")
        }
        button("完成 / 撤销", 130, 198, 160, 1) {
            [weak self] in self?.perform("done")
        }
        button("删除", 300, 198, 110, 1) {
            [weak self] in self?.perform("delete")
        }
        title("取回只会复制，纸条仍留在这里。", 268, 1)
        title("一起安静一会儿。", 26, 2)
        minutes.frame = NSRect(x: 0, y: 88, width: 80, height: 34)
        panes[2].addSubview(minutes)
        title("分钟", 94, 2)
        // Put the unit beside the field, not over it.
        panes[2].subviews.last?.frame.origin.x = 96
        button("开始专注", 0, 151, 180, 2) {
            [weak self] in self?.perform("focus")
        }
        button("结束计时", 192, 151, 160, 2) {
            [weak self] in self?.perform("cancel")
        }
        focusStatus.frame = NSRect(x: 0, y: 223, width: 560, height: 55)
        focusStatus.font = .systemFont(ofSize: 16)
        panes[2].addSubview(focusStatus)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 572, height: 330))
        scroll.hasVerticalScroller = true
        scroll.documentView = cards
        cards.frame = NSRect(x: 0, y: 0, width: 550, height: 970)
        cards.setAccessibilityElement(true)
        cards.setAccessibilityLabel("成就卡册")
        panes[3].addSubview(scroll)
        feedback.frame = NSRect(x: 24, y: 418, width: 572, height: 24)
        feedback.font = .systemFont(ofSize: 11)
        feedback.textColor = moss
        v.addSubview(feedback)
        w.center()
        tabChanged()
        refresh()
    }
    @objc func tabChanged() {
        for (i, p) in panes.enumerated() {
            p.isHidden = i != tabs.selectedSegment
        }
    }
    @objc func guestChanged() {
        refreshPortrait()
    }
    func refreshPortrait() {
        guard let e = engine, ids.indices.contains(guests.indexOfSelectedItem) else {
            portrait.kind = .adult
            return
        }
        portrait.kind =
            e.state.residents.first {
                $0.id == ids[guests.indexOfSelectedItem]
            }?.kind ?? .adult
    }
    func importFriend() {
        let alert = NSAlert()
        alert.messageText = "接朋友入住"
        alert.informativeText = "粘贴朋友发来的领养码。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 330, height: 30))
        alert.accessoryView = field
        alert.addButton(withTitle: "接它回家")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            engine?.lifeAction("adopt", id: nil, text: field.stringValue, note: nil)
            refresh()
        }
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    func refresh() {
        guard let e = engine else {
            return
        }
        e.state.ensureLife()
        let life = e.state.life!
        let selected = guests.indexOfSelectedItem
        let old = ids.indices.contains(selected) ? ids[selected] : nil
        ids = e.state.residents.filter {
            $0.live && (life.bonds[$0.id.uuidString.lowercased()] != nil || e.visits[$0.id]?.hidden == false)
        }.map {
            $0.id
        }
        guests.removeAllItems()
        for id in ids {
            let r = e.state.residents.first {
                $0.id == id
            }!
            let b = life.bonds[id.uuidString.lowercased()]
            guests.addItem(
                withTitle:
                    "\(b?.name.isEmpty == false ? b!.name : r.kind == .mouse ? "小老鼠" : r.kind == .catPaw ? "猫咪" : "旮杂") \(b?.partner == true ? "· 我的伙伴" : "")"
            )
        }
        if let old = old, let i = ids.firstIndex(of: old) {
            guests.selectItem(at: i)
        }
        if ids.isEmpty {
            guests.addItem(withTitle: "尚未遇见住客 · 回主面板撒点面包屑，或等待来访")
        }
        let oldNote = notes.indexOfSelectedItem
        noteIDs = life.notes.map {
            $0.id
        }
        notes.removeAllItems()
        for n in life.notes {
            notes.addItem(
                withTitle: (n.done ? "✓ " : "○ ") + String(n.text.prefix(45)).replacingOccurrences(of: "\n", with: " "))
        }
        if oldNote >= 0 && oldNote < noteIDs.count {
            notes.selectItem(at: oldNote)
        }
        if noteIDs.isEmpty {
            notes.addItem(withTitle: "暂无纸条 · 输入内容后点收好")
        }
        feedback.stringValue = e.message
        refreshPortrait()
        focusStatus.stringValue =
            life.focusRemaining > 0 ? "还剩 \(Int(ceil(life.focusRemaining/60))) 分钟 · 大家都在休息" : "计时期间，不会有小动物突然跑出来。"
        cards.life = life
        cards.message = e.message
        cards.needsDisplay = true
        report.string =
            "\(e.message)\n\n脚印：\(life.traceReady ? "发现了碎屑，点探索追踪" : "等待住客留下痕迹")  · 安全窝：\(life.safeLeft ? "开启" : "关闭")  · 专注剩余：\(Int(life.focusRemaining)) 秒\n\n"
            + Life.achievements.map {
                key, name in
                life.cards[key].map {
                    "✓ \(name) · " + Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .shortened)
                } ?? "○ \(name)"
            }.joined(separator: "\n")
        cards.setAccessibilityValue(report.string)
    }
    func perform(_ action: String) {
        guard let e = engine else {
            return
        }
        let i = guests.indexOfSelectedItem
        let id = ids.indices.contains(i) ? ids[i] : nil
        let n = notes.indexOfSelectedItem
        let note = noteIDs.indices.contains(n) ? noteIDs[n] : nil
        e.lifeAction(action, id: id, text: input.stringValue, note: note, minutes: Double(minutes.stringValue) ?? 25)
        refresh()
    }
}
extension Paradise {
    @objc func showLife() {
        if lifeController == nil {
            lifeController = LifeController(self)
        }
        lifeController?.refresh()
        lifeController?.showWindow(nil)
        lifeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func summon(_ id: UUID, _ now: Double) {
        guard !paused && !state.focusing,
            let i = state.residents.firstIndex(where: {
                $0.id == id
            }),
            let f = NSScreen.main?.frame
        else {
            return
        }
        let kind = state.residents[i].kind
        state.residents[i].x = kind == .catPaw ? f.maxX - 220 : f.midX - 80
        state.residents[i].y = f.minY + 170
        if kind == .catPaw {
            state.residents[i].born = now - 2
        }
        visits[id] = Visit(
            hidden: false, exiting: false, deadline: now + 8,
            target: CGPoint(x: state.residents[i].x + 80, y: state.residents[i].y), screen: f)
        let observed = state.residents[i]
        state.life?.observe(observed, now)
        syncPanels()
    }
    func lifeAction(
        _ action: String, id: UUID?, text: String, note: String?, minutes: Double = 25, inPlace: Bool = false
    ) {
        blindSession?.action(action, entity: id?.uuidString ?? "", time: state.world?.time ?? 0)
        state.ensureLife()
        let now = Date().timeIntervalSince1970
        let administrative = ["stash", "return", "done", "delete", "share", "cancel"]
        if (paused || state.focusing) && !administrative.contains(action) {
            tell("先结束专注或继续桌宠，再进行动物互动")
            return
        }
        var result = ""
        switch action {
        case "stash":
            let count = state.life!.notes.count
            result = state.life!.stash(text, now)
            if state.life!.notes.count > count, !state.focusing, !paused, let id = id,
                let i = state.residents.firstIndex(where: {
                    $0.id == id
                })
            {
                summon(id, now)
                state.residents[i].carryUntil = now + 4
            }
        case "return", "done", "delete":
            if let note = note,
                let i = state.life!.notes.firstIndex(where: {
                    $0.id == note
                })
            {
                if action == "return" {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.life!.notes[i].text, forType: .string)
                    state.life!.award("stash.return", now)
                    result = "已复制纸条，原内容仍保留"
                }
                if action == "done" {
                    state.life!.notes[i].done.toggle()
                    result = "待办状态已更新"
                }
                if action == "delete" {
                    state.life!.notes.remove(at: i)
                    result = "已删除选中的纸条"
                }
            } else {
                result = "先选一条纸条"
            }
        case "focus":
            state.life!.focusRemaining = max(1, min(120, minutes.isFinite ? minutes : 25)) * 60
            for r in state.residents where r.live {
                visits[r.id] = Visit()
            }
            result = "专注开始，大家回窝了；关闭程序不会自动完成计时"
        case "cancel":
            state.life!.focusRemaining = 0
            nextAppearance = now + 20
            result = "计时已结束，不扣好感"
        case "safe":
            state.life!.safeLeft.toggle()
            result = "左半屏安全窝已" + (state.life!.safeLeft ? "开启" : "关闭")
        case "explore":
            state.ensureWorld()
            guard
                let h = state.world!.habitats.firstIndex(where: {
                    $0.nest && $0.exposed && !$0.discovered
                })
            else {
                tell("这里还没有新的痕迹")
                return
            }
            let location = state.world!.habitats[h].id
            state.world!.habitats[h].discovered = true
            state.life!.traceReady = false
            state.life!.award("trace.first", now)
            state.life!.award("nest.first", now)
            for c in state.world!.creatures.filter({
                $0.location == location && $0.roach
            }).prefix(2) {
                if let id = UUID(uuidString: c.id) {
                    summon(id, now)
                }
            }
            result = "缝隙里有一处住过的窝。"
        case "coexist":
            let partners = state.life!.bonds.filter {
                $0.value.partner
            }
            let species = Set(
                partners.values.map {
                    $0.kind == "mouse" ? "mouse" : $0.kind == "catPaw" ? "cat" : "roach"
                })
            guard species.count >= 2 else {
                tell("先认识至少两种伙伴，再安排大家共居")
                return
            }
            state.life!.safeLeft = true
            // Shared home is established; visits remain staggered so no chase interrupts it.
            let guests = state.residents.filter {
                state.life!.bonds[$0.id.uuidString.lowercased()]?.partner == true
            }
            var seen = Set<String>()
            for r in guests {
                let kind = r.kind == .mouse ? "mouse" : r.kind == .catPaw ? "cat" : "roach"
                if seen.insert(kind).inserted {
                    summon(r.id, now)
                    if let i = state.residents.firstIndex(where: {
                        $0.id == r.id
                    }), let f = NSScreen.main?.frame {
                        state.residents[i].x = kind == "roach" ? f.minX + 60 : f.maxX - petCanvas(r.kind).width - 20
                        state.residents[i].y = f.minY + (kind == "mouse" ? 310 : 170)
                        visits[r.id]?.target = CGPoint(x: state.residents[i].x, y: state.residents[i].y)
                    }
                }
            }
            state.life!.award("coexist.first", now)
            result = "左侧留窝、右侧巡逻，伙伴错时来访；共居安排完成"
        case "adopt":
            guard state.residents.count < maxResidents else {
                tell("住客已满，先保留领养码，腾出空间后再接收")
                return
            }
            let (r, msg) = state.life!.adopt(text.trimmingCharacters(in: .whitespacesAndNewlines), now)
            result = msg
            if let r = r {
                state.residents.append(r)
                summon(r.id, now)
            }
        default:
            guard let id = id,
                let r = state.residents.first(where: {
                    $0.id == id && $0.live
                })
            else {
                tell("先选择一位住客；可撒面包屑邀请旮杂")
                return
            }
            if action == "share" {
                if let code = state.life!.share(id, now) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    result = "领养码已复制。副本领养，不带纸条和资源"
                } else {
                    result = "先命名或培养成伙伴，再生成领养码"
                }
            } else if action == "patrol" {
                guard r.friend, state.life!.bonds[id.uuidString.lowercased()]?.partner == true else {
                    tell("请选择已成为伙伴的老鼠或猫")
                    return
                }
                guard now >= state.life!.guardUntil else {
                    tell("伙伴还在值班，右半屏正在保持安静")
                    return
                }
                let targets = state.residents.filter {
                    $0.live && !$0.friend && !state.protected($0) && visits[$0.id]?.hidden == false
                        && $0.x >= (visits[$0.id]?.screen.midX ?? 0)
                }
                for t in targets {
                    visits[t.id] = Visit()
                }
                state.life!.guardSide = "right"
                state.life!.guardUntil = now + 60
                summon(id, now)
                if !targets.isEmpty {
                    state.life!.award(r.kind == .mouse ? "patrol.first" : "guard.first", now)
                }
                result = "右半屏值班 60 秒 · 驱赶 \(targets.count) 只；不伤害伙伴、不产生击杀奖励"
            } else if action == "gold" {
                guard r.kind == .gold, (state.life!.bonds[id.uuidString.lowercased()]?.trust ?? 0) >= 2 else {
                    tell("它还护着卵壳，再和它熟悉一点吧")
                    return
                }
                let amount = state.life!.gold(id, now)
                state.progression!.shells += amount
                result = amount > 0 ? "它留给你 2 枚黄金卵壳，仍可以继续做朋友" : "这位住客的卵壳已收获过啦"
            } else {
                if !inPlace {
                    summon(id, now)
                }
                result =
                    action == "recall" ? "它听见你了，出来见一面" : state.life!.interact(r, action: action, text: text, now: now)
            }
        }
        if let id = id, ["pet", "feed"].contains(action) {
            state.worldSignal("friendly", id: id)
            if action == "feed" {
                state.worldSignal("food", id: id)
            }
        }
        state.reconcileWorld()
        tell(result)
        syncPanels()
        save()
        rebuildMenu()
    }
}
final class TraceCrumbView: NSView {
    weak var engine: Paradise?
    override func draw(_ dirtyRect: NSRect) {
        for n in 0..<5 {
            oval(NSRect(x: 5 + n * 7, y: 5 + n % 3 * 3, width: 4, height: 3), color(0xA7814C, 0.7))
        }
    }
    override func mouseDown(with event: NSEvent) {
        engine?.lifeAction("explore", id: nil, text: "", note: nil)
    }
}
extension Paradise {
    func syncTrace() {
        guard !isTestRun else {
            return
        }
        if !paused && !state.quiet && !state.focusing,
            let h = state.world?.habitats.first(where: {
                $0.nest && $0.exposed && !$0.discovered
            })
        {
            if tracePanel == nil {
                let p = PetPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 44, height: 24),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                p.isOpaque = false
                p.backgroundColor = .clear
                p.level = .floating
                p.hasShadow = false
                p.isReleasedWhenClosed = false
                p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                let v = TraceCrumbView(frame: NSRect(x: 0, y: 0, width: 44, height: 24))
                v.engine = self
                p.contentView = v
                tracePanel = p
            }
            let point = habitatAnchor(h.id)
            tracePanel?.setFrameOrigin(NSPoint(x: point.x + 60, y: point.y + 4))
            if tracePanel?.isVisible != true {
                tracePanel?.orderFrontRegardless()
            }
        } else if tracePanel?.isVisible == true {
            tracePanel?.orderOut(nil)
        }
    }
}
