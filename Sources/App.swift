import AppKit
import ApplicationServices

final class ActionButton: NSButton {
    var actionBlock: (() -> Void)?
    var fillColor = color(0xE8E9DB)
    var textColor = ink
    var small = false
    init(_ title: String, frame: NSRect, fill: NSColor = color(0xE8E9DB), action: @escaping () -> Void) {
        super.init(frame: frame); self.title=title; self.fillColor=fill; self.actionBlock=action
        self.target=self; self.action=#selector(fire); self.bezelStyle = .regularSquare; self.isBordered=false
        self.setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func fire() { actionBlock?() }
    override func draw(_ dirtyRect: NSRect) {
        paintRect(bounds.insetBy(dx:1,dy:1),isHighlighted ? fillColor.blended(withFraction:0.14,of:ink)! : fillColor,radius:12)
        let font = NSFont.systemFont(ofSize:small ? 12 : 14,weight:.semibold)
        let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:isEnabled ? textColor : textColor.withAlphaComponent(0.42)]
        let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center;paragraph.lineBreakMode = .byTruncatingTail
        var centered=attrs;centered[.paragraphStyle]=paragraph
        (title as NSString).draw(in:NSRect(x:8,y:(bounds.height-font.pointSize*1.4)/2,width:bounds.width-16,height:font.pointSize*1.6),withAttributes:centered)
    }
}
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class EffectView:NSView {
    let tool:Tool
    override var isFlipped:Bool {true}
    init(tool:Tool) {self.tool=tool;super.init(frame:NSRect(x:0,y:0,width:146,height:140))}
    required init?(coder:NSCoder) {fatalError()}
    override func draw(_ dirtyRect:NSRect) {
        let text:String
        switch tool {case .pinch:text="噗叽！";case .slipper:text="啪！";case .vacuum:text="咻——";case .cleaner:text="亮晶晶 ✧";case .poison:text="躺平。"}
        paintRect(NSRect(x:23,y:25,width:100,height:32),cream,radius:15,stroke:ink,width:2)
        label(text,35,30,size:16,weight:.heavy,c:tool == .slipper ? orange : moss,width:90)
        if tool == .vacuum {
            for n in 0..<3 {line([NSPoint(x:25,y:70+CGFloat(n)*12),NSPoint(x:77,y:65+CGFloat(n)*9),NSPoint(x:106,y:75)],moss,2)}
        } else if tool == .slipper {
            oval(NSRect(x:91,y:67,width:24,height:51),color(0xE9AF6D),stroke:ink,width:2)
            line([NSPoint(x:95,y:91),NSPoint(x:104,y:82),NSPoint(x:112,y:94)],moss,3)
        } else {
            for n in 0..<5 {let a=Double(n)*1.26;line([NSPoint(x:73+cos(a)*25,y:91+sin(a)*19),NSPoint(x:73+cos(a)*37,y:91+sin(a)*29)],tool == .cleaner ? moss : orange,2)}
        }
    }
}
final class PetView: NSView {
    weak var engine: Paradise?
    var id: UUID
    override var isFlipped: Bool { true }
    init(id: UUID, engine: Paradise) { self.id=id; self.engine=engine; super.init(frame:NSRect(x:0,y:0,width:146,height:140)); setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel("桌面旮杂，点击使用当前工具") }
    required init?(coder:NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        guard let e=engine, let r=e.state.residents.first(where:{$0.id==id}) else {return}
        let now=Date().timeIntervalSince1970
        let size: CGFloat = r.kind == .baby ? 67 : r.kind == .egg ? 75 : 98
        drawBug(in:NSRect(x:(146-size)/2,y:140-size,width:size,height:size),kind:r.kind,phase:now,flying:r.flyingUntil>now,facing:r.vx>=0 ? 1 : -1)
        if r.tauntUntil>now {
            paintRect(NSRect(x:3,y:7,width:140,height:27),cream,radius:12,stroke:ink)
            label(r.flyingUntil>now ? "打不到～我会飞！" : "你以为没有了？",13,11,size:11,weight:.semibold,width:128)
        }
    }
    override func mouseDown(with event:NSEvent) { engine?.interact(id) }
    override func accessibilityPerformPress() -> Bool { engine?.interact(id); return true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.pointingHand) }
}

final class Dashboard: NSView {
    weak var engine: Paradise?
    var tools:[Tool:ActionButton]=[:]
    var pauseButton:ActionButton!
    var quietButton:ActionButton!
    var finderButton:ActionButton!
    override var isFlipped: Bool { true }
    init(engine:Paradise) {
        self.engine=engine; super.init(frame:NSRect(x:0,y:0,width:980,height:748))
        func button(_ title:String,_ frame:NSRect,_ fill:NSColor = color(0xE8E9DB),_ action:@escaping ()->Void) -> ActionButton {
            let b=ActionButton(title,frame:frame,fill:fill,action:action); addSubview(b); return b
        }
        _ = button("＋ 撒点面包屑",NSRect(x:55,y:281,width:162,height:43),moss,{[weak engine] in engine?.feed()}); (subviews.last as? ActionButton)?.textColor=cream
        _ = button("放它们去桌面 ↗",NSRect(x:229,y:281,width:172,height:43),color(0xE6E7D7),{[weak engine] in engine?.release()})
        _ = button("▰  工作资料",NSRect(x:62,y:408,width:164,height:60),color(0xEDCE91),{[weak engine] in engine?.previewFolder("工作资料",point:NSPoint(x:120,y:450))})
        _ = button("▰  绝对干净",NSRect(x:244,y:408,width:164,height:60),color(0xEDCE91),{[weak engine] in engine?.previewFolder("绝对干净",point:NSPoint(x:300,y:450))})
        finderButton=button("连接 Finder ↗",NSRect(x:683,y:438,width:230,height:34),color(0xE6E7D7),{[weak engine] in engine?.connectFinder()})
        for (n,tool) in Tool.allCases.enumerated() {
            let b=button(tool.title,NSRect(x:40+CGFloat(n)*183,y:537,width:172,height:62),color(0xE8E9DB),{[weak engine] in engine?.select(tool)})
            tools[tool]=b
        }
        pauseButton=button("暂停桌宠",NSRect(x:613,y:672,width:106,height:35),color(0xE8E9DB),{[weak engine] in engine?.togglePause()}); pauseButton.small=true
        quietButton=button("专注模式",NSRect(x:727,y:672,width:106,height:35),color(0xE8E9DB),{[weak engine] in engine?.toggleQuiet()}); quietButton.small=true
        let hide=button("收起面板 ↗",NSRect(x:841,y:672,width:99,height:35),color(0xE8E9DB),{[weak engine] in engine?.window.orderOut(nil)}); hide.small=true
    }
    required init?(coder:NSCoder) { fatalError() }
    func refresh() {
        guard let e=engine else{return}
        for (tool,b) in tools {
            let unlocked=e.state.xp>=tool.threshold
            b.title=unlocked ? tool.title+(e.state.tool==tool ? "  ✓" : "") : tool.title + " · " + String(tool.threshold) + " 点"
            b.fillColor=e.state.tool==tool ? moss : unlocked ? color(0xE8E9DB) : color(0xEFEEE5)
            b.textColor=e.state.tool==tool ? cream : unlocked ? ink : color(0x96988B)
            b.needsDisplay=true
        }
        pauseButton.title=e.paused ? "继续桌宠" : "暂停桌宠"
        quietButton.title=e.state.quiet ? "专注中 ✓" : "专注模式"
        finderButton.title=AXIsProcessTrusted() ? "Finder 已连接 ✓" : "连接 Finder ↗"
        needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let e=engine else{return}; let g=e.state
        paintRect(bounds,cream)
        label("旮旯乐园",40,29,size:25,weight:.heavy)
        label("G A L A   P A R A D I S E",41,64,size:9,weight:.bold,c:moss)
        paintRect(NSRect(x:737,y:36,width:203,height:31),color(0xE7E9DA),radius:15)
        oval(NSRect(x:752,y:47,width:7,height:7),e.paused ? orange : moss)
        label(e.paused ? "暂时安静 · 桌宠已暂停" : "桌面生态运行中 · 本地存档",768,42,size:11,weight:.medium)
        line([NSPoint(x:40,y:93),NSPoint(x:940,y:93)],color(0xDDDECF),1)
        paintRect(NSRect(x:40,y:114,width:900,height:233),color(0xE8EBD9),radius:22)
        label("一只旮杂，整台电脑的热闹。",56,133,size:11,weight:.semibold,c:moss)
        label("欢迎入住，",54,158,size:35,weight:.heavy)
        label("你的电脑有新房客。",54,200,size:35,weight:.heavy)
        label("喂一点，养一窝。清干净了？它可不这么想。",57,253,size:13,c:color(0x6F7562))
        // Character display with a paper specimen tag.
        oval(NSRect(x:674,y:167,width:208,height:150),color(0xD7DCC2))
        drawBug(in:NSRect(x:682,y:132,width:192,height:192),phase:Date().timeIntervalSince1970)
        paintRect(NSRect(x:810,y:143,width:94,height:30),cream,radius:13)
        label("你好，室友。",821,149,size:11,weight:.medium)
        label("NO. 001 / 旮杂",721,316,size:10,weight:.bold,c:moss)
        label("01  /  文件夹栖息地",40,367,size:15,weight:.bold)
        label("点开看看，里面可能有惊喜。",40,389,size:11,c:color(0x7A7D6C))
        label(g.poisoned ? "已投药 · 成虫躺平，卵仍然会孵化" : "试玩文件夹 · 点击即有旮杂跑出来",64,478,size:11,c:g.poisoned ? orange : color(0x858573))
        paintRect(NSRect(x:446,y:372,width:494,height:117),color(0xEFEEE4),radius:17)
        let live=g.residents.filter{$0.live}.count, eggs=g.residents.filter{$0.kind == .egg}.count, mess=g.residents.filter{$0.kind == .stain || $0.kind == .corpse}.count
        for (n,pair) in [("住客",live),("卵窝",eggs),("待清洁",mess)].enumerated() {
            let x:CGFloat=468+CGFloat(n)*80
            label("\(pair.1)",x,388,size:25,weight:.bold)
            label(pair.0,x,422,size:10,c:color(0x777E69))
        }
        label("真正藏进 Finder",701,388,size:15,weight:.bold)
        label("授权辅助功能后，打开文件夹触发出逃。",701,414,size:10,c:color(0x777E69),width:225)
        label("02  /  旮杂应对工具箱",40,510,size:15,weight:.bold)
        label("喂食 +3  ·  捕捉 +2  ·  清洁 +2",716,513,size:11,c:color(0x7A7D6C))
        for (n,tool) in Tool.allCases.enumerated() {
            let descriptions=["噗叽！会留奶油污渍","啪！但它可能会飞","开文件夹时批量躺平","活的、死的、卵，都能吸","最后一步：把污渍擦掉"]
            label(descriptions[n],45+CGFloat(n)*183,607,size:10,c:color(0x818572),width:171)
            if tool == .poison && g.poisoned { oval(NSRect(x:558,y:544,width:6,height:6),orange) }
        }
        line([NSPoint(x:40,y:641),NSPoint(x:940,y:641)],color(0xDDDECF),1)
        label("LV.\(g.level)  共生计划",40,660,size:12,weight:.bold,c:moss)
        label("\(g.xp) 生长点",199,662,size:11,c:moss)
        paintRect(NSRect(x:40,y:686,width:234,height:5),color(0xDFE1D1),radius:2)
        paintRect(NSRect(x:40,y:686,width:234*min(1,CGFloat(g.xp)/28),height:5),moss,radius:2)
        label(g.unlocked.count==5 ? "全工具已解锁 · 旮杂永远有下一招" : "下一件：\(Tool.allCases.first{$0.threshold>g.xp}!.title)",40,700,size:10,c:color(0x818572))
        label(e.message,300,665,size:12,weight:.medium,c:orange,width:302)
        label(g.tool.detail,300,689,size:10,c:color(0x818572),width:302)
        label("菜单栏「旮」随时召回  ·  ⌘Q 退出  ·  污渍仅为桌宠图层",40,728,size:9,c:color(0x959887))
    }
}

final class Paradise: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var state=GameState()
    var isTestRun:Bool { CommandLine.arguments.contains("--smoke") || CommandLine.arguments.contains("--render") || CommandLine.arguments.contains("--integration-test") }
    var window:NSWindow!
    var dashboard:Dashboard!
    var status:NSStatusItem!
    var panels:[UUID:PetPanel]=[:]
    var timer:Timer?
    var paused=false
    var pauseStarted:Double=0
    var message="它们已经准备好入住了。"
    var tickCount=0
    var lastFinder=""
    var lastFeed:Double=0
    var lastFolder:Double=0
    var lastHatch:Double=Date().timeIntervalSince1970
    var emptySince:Double=0
    var frameTime=Date().timeIntervalSince1970
    let maxResidents=38
    var saveURL:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("GalaParadise/save.json") }
    func applicationDidFinishLaunching(_ notification:Notification) {
        load()
        let menu=NSMenu(); let appItem=NSMenuItem(); menu.addItem(appItem); let appMenu=NSMenu(); appMenu.addItem(withTitle:"关于旮旯乐园",action:#selector(showDashboard),keyEquivalent:""); appMenu.addItem(.separator()); appMenu.addItem(withTitle:"退出旮旯乐园",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); appItem.submenu=appMenu; NSApp.mainMenu=menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:980,height:748),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="旮旯乐园 · Gala Paradise"; window.titlebarAppearsTransparent=true; window.backgroundColor=cream; window.isReleasedWhenClosed=false; window.delegate=self
        dashboard=Dashboard(engine:self); window.contentView=dashboard; window.center()
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength); status.button?.title="旮"
        rebuildMenu()
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        if state.residents.isEmpty && state.xp==0 { spawn(.adult); spawn(.baby) }
        syncPanels(); showDashboard()
        timer=Timer.scheduledTimer(timeInterval:1.0/30.0,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        if CommandLine.arguments.contains("--render") { DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { self.renderPreview(); NSApp.terminate(nil) } }
        if CommandLine.arguments.contains("--integration-test") { DispatchQueue.main.asyncAfter(deadline:.now()+0.3) { self.integrationTest(); NSApp.terminate(nil) } }
        if CommandLine.arguments.contains("--smoke") { DispatchQueue.main.asyncAfter(deadline:.now()+2) { self.folderBurst(name:"自动验收",at:nil); self.feed(); self.select(.pinch); print("SMOKE: window=\(self.window.isVisible), sprites=\(self.panels.count), xp=\(self.state.xp)"); NSApp.terminate(nil) } }
    }
    func rebuildMenu() {
        let m=NSMenu()
        func item(_ title:String,_ action:Selector,_ key:String="") { let i=NSMenuItem(title:title,action:action,keyEquivalent:key); i.target=self; m.addItem(i) }
        item("打开旮旯乐园",#selector(showDashboard)); item("撒点面包屑  +3",#selector(feed)); item(paused ? "继续桌宠" : "暂停并隐藏桌宠",#selector(togglePause)); item(state.quiet ? "关闭专注模式" : "开启专注模式",#selector(toggleQuiet))
        m.addItem(.separator())
        for t in Tool.allCases { let i=NSMenuItem(title:state.xp>=t.threshold ? t.title : "\(t.title)（\(t.threshold) 点解锁）",action:#selector(menuTool(_:)),keyEquivalent:""); i.target=self; i.representedObject=t.rawValue; i.state=state.tool==t ? .on : .off; m.addItem(i) }
        if state.poisoned { item("收起蟑螂药",#selector(removePoison)) }
        m.addItem(.separator()); item("退出旮旯乐园",#selector(quit),"q"); status.menu=m
    }
    @objc func menuTool(_ sender:NSMenuItem) { if let raw=sender.representedObject as? String,let t=Tool(rawValue:raw) {select(t)} }
    @objc func showDashboard() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); dashboard.refresh() }
    @objc func quit() { NSApp.terminate(nil) }
    func windowWillClose(_ notification:Notification) { tell("面板已收起，菜单栏「旮」可以召回") }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    func applicationWillTerminate(_ notification:Notification) {save(); panels.values.forEach{$0.orderOut(nil)}}
    func tell(_ text:String) { message=text; dashboard?.refresh() }
    func select(_ tool:Tool) {
        guard state.xp>=tool.threshold else {tell("还差 \(tool.threshold-state.xp) 点，喂食或捉旮杂来解锁"); return}
        state.tool=tool
        if tool == .poison { state.poisoned=true; tell("药已放好。再打开文件夹，看看里面……") } else { tell("已拿起\(tool.title)。点击桌面上的目标") }
        save(); rebuildMenu(); dashboard.refresh()
    }
    @objc func removePoison() { state.poisoned=false; if state.tool == .poison {state.tool = .pinch}; tell("蟑螂药已收起，住客恢复正常出逃"); save(); rebuildMenu() }
    @objc func feed() {
        let now=Date().timeIntervalSince1970
        guard !paused else {tell("先继续桌宠，再投喂吧"); return}
        guard now-lastFeed>2 else {tell("嚼嚼嚼……稍等两秒再喂"); return}; lastFeed=now
        state.fed+=1; state.gain(3); spawn(.adult)
        if state.fed%2==0 {spawn(.egg)}
        tell("面包屑 +3 生长点。旮杂：还有吗？")
        save(); rebuildMenu(); syncPanels()
    }
    func release() {
        if paused {togglePause()}
        if state.residents.filter({$0.live}).count<4 {spawn(.adult);spawn(.baby)}
        syncPanels(); tell("它们去桌面串门了。菜单栏「旮」召回面板")
        window.orderOut(nil)
    }
    @objc func togglePause() {
        paused.toggle()
        if paused { pauseStarted=Date().timeIntervalSince1970;panels.values.forEach{$0.orderOut(nil)} } else {
            let now=Date().timeIntervalSince1970, delta=now-pauseStarted
            for i in state.residents.indices {state.residents[i].born+=delta;state.residents[i].flyingUntil+=delta;state.residents[i].tauntUntil+=delta}
            lastHatch+=delta;if emptySince>0 {emptySince+=delta}
            frameTime=now;panels.values.forEach{$0.orderFrontRegardless()}
        }
        tell(paused ? "全体暂停并隐藏，可以安心办公" : "住客们回来啦"); rebuildMenu()
    }
    @objc func toggleQuiet() {state.quiet.toggle(); tell(state.quiet ? "专注中：住客减速，停止繁殖和突然出逃" : "专注结束，角落又热闹起来了");save();rebuildMenu()}
    func connectFinder() {
        if AXIsProcessTrusted() {tell("Finder 已连接；打开或切换文件夹试试");return}
        let opts=["AXTrustedCheckOptionPrompt":true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        tell("在系统设置中允许「旮旯乐园」辅助功能，回来即生效")
        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {NSWorkspace.shared.open(url)}
    }
    func previewFolder(_ name:String,point:NSPoint) {
        let p=window.convertPoint(toScreen:dashboard.convert(point,to:nil))
        folderBurst(name:name,at:p)
    }
    func folderBurst(name:String,at point:NSPoint?) {
        guard !paused && !state.quiet else {tell("当前已暂停或专注中，文件夹里的住客先不打扰");return}
        let now=Date().timeIntervalSince1970
        guard now-lastFolder>1.2 else {return};lastFolder=now
        state.foldersOpened+=1;state.gain(1)
        for _ in 0..<3 {spawn(state.poisoned ? .corpse : .adult,at:point)}
        if state.residents.filter({$0.kind == .egg}).count<7 {spawn(.egg)}
        tell(state.poisoned ? "「\(name)」一片躺平……但卵没事。" : "「\(name)」开门！三只旮杂溜出来了")
        save();rebuildMenu();syncPanels()
    }
    func interact(_ id:UUID) {
        guard !paused else{return}
        let old=state.unlocked.count
        let before=state.residents.first{$0.id==id}
        let msg=state.use(state.tool,on:id,now:Date().timeIntervalSince1970,flightRoll:Double.random(in:0...1))
        if state.unlocked.count>old {tell(msg+" · 新工具解锁！")} else {tell(msg)}
        if let before=before {
            let after=state.residents.first{$0.id==id}
            if after == nil || (before.live && after?.live == false) {showEffect(state.tool,at:NSPoint(x:before.x,y:before.y))}
        }
        save();syncPanels();rebuildMenu()
    }
    func showEffect(_ tool:Tool,at point:NSPoint) {
        guard !isTestRun else{return}
        let panel=PetPanel(contentRect:NSRect(x:point.x,y:point.y+30,width:146,height:140),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.ignoresMouseEvents=true;panel.level = .floating;panel.isReleasedWhenClosed=false;panel.hidesOnDeactivate=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        panel.contentView=EffectView(tool:tool);panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({context in
            context.duration=0.55
            panel.animator().alphaValue=0
            panel.animator().setFrameOrigin(NSPoint(x:point.x,y:point.y+64))
        },completionHandler:{panel.close()})
    }
    func spawn(_ kind:BugKind,at point:NSPoint?=nil,taunt:Bool=false) {
        guard state.residents.count<maxResidents,let screen=NSScreen.main else{return}
        let f=screen.visibleFrame
        var x=Double.random(in:Double(f.minX+15)...Double(max(f.minX+16,f.maxX-160)))
        var y=Double.random(in:Double(f.minY+10)...Double(max(f.minY+11,f.maxY-160)))
        if kind == .egg { x=Bool.random() ? f.minX+3 : f.maxX-145; y=f.minY+Double.random(in:0...80) }
        else if let p=point { x=p.x+Double.random(in:0...150); y=p.y+Double.random(in:-50...30) }
        let now=Date().timeIntervalSince1970
        var r=Resident(kind:kind,x:x,y:y,born:now,vx:Double.random(in:25...65)*(Bool.random() ? 1 : -1),vy:Double.random(in:-30...30))
        if taunt {r.tauntUntil=now+4}
        state.residents.append(r)
    }
    func syncPanels() {
        let ids=Set(state.residents.map{$0.id})
        for id in Array(panels.keys) where !ids.contains(id) {panels[id]?.close();panels.removeValue(forKey:id)}
        for r in state.residents where panels[r.id]==nil {
            let p=PetPanel(contentRect:NSRect(x:r.x,y:r.y,width:146,height:140),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.ignoresMouseEvents=true;p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=false;p.level = .floating;p.isReleasedWhenClosed=false;p.hidesOnDeactivate=false
            p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle];p.isMovableByWindowBackground=false
            p.contentView=PetView(id:r.id,engine:self);panels[r.id]=p
            if !paused {p.orderFrontRegardless()}
        }
        dashboard?.refresh()
    }
    @objc func screenChanged() {
        guard let f=NSScreen.main?.visibleFrame else{return}
        for i in state.residents.indices {state.residents[i].x=min(max(state.residents[i].x,f.minX),f.maxX-146);state.residents[i].y=min(max(state.residents[i].y,f.minY),f.maxY-140)}
    }
    @objc func tick() {
        let now=Date().timeIntervalSince1970;let dt=min(0.1,now-frameTime);frameTime=now
        guard !paused else{return};tickCount+=1
        for i in state.residents.indices {
            var r=state.residents[i]
            if r.live {
                let factor=(r.flyingUntil>now ? 4.0 : 1.0)*(state.quiet ? 0.23 : 1.0)
                r.x+=r.vx*dt*factor;r.y+=r.vy*dt*factor
                let f=(NSScreen.screens.first{$0.frame.contains(NSPoint(x:r.x+73,y:r.y+70))} ?? NSScreen.main)?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
                if r.x<f.minX {r.x=f.minX;r.vx=abs(r.vx)}
                if r.x>f.maxX-146 {r.x=f.maxX-146;r.vx = -abs(r.vx)}
                if r.y<f.minY {r.y=f.minY;r.vy=abs(r.vy)}
                if r.y>f.maxY-140 {r.y=f.maxY-140;r.vy = -abs(r.vy)}
                if tickCount%150==0 && Int.random(in:0...3)==0 {r.vy=Double.random(in:-40...40);r.vx = -r.vx}
                if r.kind == .baby && now-r.born>120 && !state.quiet {r.kind = .adult}
                state.residents[i]=r
            }
            panels[r.id]?.setFrameOrigin(NSPoint(x:r.x,y:r.y));panels[r.id]?.contentView?.needsDisplay=true
            // Only the visible character captures clicks; the rest of the desktop remains usable.
            let size:Double = r.kind == .baby ? 67 : r.kind == .egg ? 75 : 98
            let hit=NSRect(x:r.x+(146-size)/2,y:r.y+size*0.1,width:size,height:size*0.9)
            panels[r.id]?.ignoresMouseEvents = !hit.contains(NSEvent.mouseLocation)
        }
        if tickCount%30==0 {
            if !state.quiet {ecology(now);checkFinder()}
            dashboard.refresh()
        }
        if tickCount%300==0 {save()}
    }
    func ecology(_ now:Double) {
        if let i=state.residents.firstIndex(where:{$0.kind == .egg && now-$0.born>55}),state.residents.count<maxResidents {
            let egg=state.residents.remove(at:i)
            spawn(.baby,at:NSPoint(x:egg.x,y:egg.y),taunt:true);spawn(.baby,at:NSPoint(x:egg.x,y:egg.y))
            tell("角落的卵孵化了。小旮杂：没想到吧？");syncPanels()
        }
        if state.residents.contains(where:{$0.live}) && now-lastHatch>75 {
            lastHatch=now
            if state.residents.filter({$0.kind == .egg}).count<5 {spawn(.egg);syncPanels()}
        }
        if !state.residents.contains(where:{$0.live}) {
            if emptySince==0 {emptySince=now}
            if now-emptySince>24 {spawn(.baby,taunt:true);emptySince=0;tell("漏网之鱼：你以为电脑干净了？");syncPanels()}
        } else {emptySince=0}
        if tickCount%1350==0 && state.residents.filter({$0.live}).count<8 {spawn(.baby,taunt:true);syncPanels()}
    }
    func checkFinder() {
        guard AXIsProcessTrusted(), let front=NSWorkspace.shared.frontmostApplication,front.bundleIdentifier=="com.apple.finder" else{return}
        let app=AXUIElementCreateApplication(front.processIdentifier)
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,kAXFocusedWindowAttribute as CFString,&value) == .success,let value=value,CFGetTypeID(value)==AXUIElementGetTypeID() else{return}
        let win=unsafeBitCast(value,to:AXUIElement.self)
        var titleValue:CFTypeRef?,docValue:CFTypeRef?,positionValue:CFTypeRef?
        AXUIElementCopyAttributeValue(win,kAXTitleAttribute as CFString,&titleValue)
        AXUIElementCopyAttributeValue(win,kAXDocumentAttribute as CFString,&docValue)
        let title=titleValue as? String ?? ""
        guard !title.isEmpty else{return}
        let key=(docValue as? String ?? "")+"|"+title
        guard key != lastFinder else{return};lastFinder=key
        var point:NSPoint?=nil
        if AXUIElementCopyAttributeValue(win,kAXPositionAttribute as CFString,&positionValue) == .success,let v=positionValue,CFGetTypeID(v)==AXValueGetTypeID() {
            var p=CGPoint.zero
            if AXValueGetValue(unsafeBitCast(v,to:AXValue.self),.cgPoint,&p) {point=NSPoint(x:p.x+40,y:(NSScreen.screens.first?.frame.maxY ?? 900)-p.y-180)}
        }
        folderBurst(name:title,at:point)
    }
    func renderPreview() {
        dashboard.refresh()
        guard let rep=dashboard.bitmapImageRepForCachingDisplay(in:dashboard.bounds) else {return}
        dashboard.cacheDisplay(in:dashboard.bounds,to:rep)
        let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
        try? rep.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/preview.png"))
        let icon=NSImage(size:NSSize(width:1024,height:1024))
        icon.lockFocusFlipped(true)
        paintRect(NSRect(x:0,y:0,width:1024,height:1024),moss,radius:220)
        oval(NSRect(x:111,y:185,width:806,height:702),color(0xDFE5C6))
        drawBug(in:NSRect(x:81,y:72,width:856,height:856),phase:0.1)
        icon.unlockFocus()
        if let tiff=icon.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff) {try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/icon.png"))}
        let sheet=NSImage(size:NSSize(width:1000,height:240))
        sheet.lockFocusFlipped(true)
        paintRect(NSRect(x:0,y:0,width:1000,height:240),cream)
        for (i,k) in [BugKind.adult,.baby,.corpse,.egg,.stain].enumerated() {
            drawBug(in:NSRect(x:CGFloat(i)*200+25,y:25,width:150,height:150),kind:k,phase:0)
            label(["旮杂","漏网之鱼","躺平","卵窝","奶油爆浆"][i],CGFloat(i)*200+60,190,size:15,weight:.semibold)
        }
        sheet.unlockFocus()
        if let tiff=sheet.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff) {try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/characters.png"))}
        print("RENDER: dashboard, icon and character sheet exported")
    }
    func integrationTest() {
        timer?.invalidate()
        state=GameState();syncPanels()
        for tool in Tool.allCases {precondition(dashboard.tools[tool]!.title.contains(tool.title))}
        dashboard.tools[.slipper]!.performClick(nil)
        precondition(state.tool == .pinch)
        folderBurst(name:"测试文件夹",at:NSPoint(x:200,y:200))
        precondition(state.residents.filter{$0.live}.count==3)
        precondition(state.residents.filter{$0.kind == .egg}.count==1)
        precondition(panels.count==4)
        state.xp=28;dashboard.tools[.poison]!.performClick(nil);lastFolder=0
        precondition(state.tool == .poison && state.poisoned)
        folderBurst(name:"投药测试",at:nil)
        precondition(state.residents.filter{$0.kind == .corpse}.count==3)
        precondition(state.residents.filter{$0.kind == .egg}.count==2)
        let now=Date().timeIntervalSince1970
        for i in state.residents.indices where state.residents[i].kind == .egg {state.residents[i].born=now-60}
        lastHatch=now;ecology(now)
        precondition(state.residents.filter{$0.kind == .baby}.count==2)
        precondition(state.residents.filter{$0.kind == .egg}.count==1)
        state.tool = .vacuum
        for id in state.residents.map({$0.id}) {interact(id)}
        precondition(state.residents.isEmpty && panels.isEmpty)
        emptySince=now-25;ecology(now)
        precondition(state.residents.count==1 && state.residents[0].kind == .baby)
        togglePause();precondition(panels.values.allSatisfy{!$0.isVisible})
        togglePause();precondition(panels.values.allSatisfy{$0.isVisible})
        toggleQuiet();let count=state.residents.count;lastFolder=0;folderBurst(name:"专注测试",at:nil)
        precondition(state.residents.count==count)
        toggleQuiet();removePoison();precondition(!state.poisoned)
        for _ in 0..<100 {spawn(.adult)}
        precondition(state.residents.count==maxResidents)
        syncPanels();precondition(panels.count==maxResidents)
        print("PASS: native window/panels, folder burst, poison spares eggs, hatch, vacuum removal, survivor, pause, focus, cap")
    }
    func load() {
        if isTestRun {return}
        guard let data=try? Data(contentsOf:saveURL) else{return}
        do {state=try JSONDecoder().decode(GameState.self,from:data);state.residents=Array(state.residents.prefix(maxResidents)); if state.xp<state.tool.threshold {state.tool = .pinch};screenChanged()} catch {message="存档暂时无法读取，本次从新乐园开始"}
        lastHatch=Date().timeIntervalSince1970
    }
    func save() {
        if isTestRun {return}
        state.lastSaved=Date().timeIntervalSince1970
        do {try FileManager.default.createDirectory(at:saveURL.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(state).write(to:saveURL,options:.atomic)} catch {message="存档写入失败：\(error.localizedDescription)"}
    }
}
