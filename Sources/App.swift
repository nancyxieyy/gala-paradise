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
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?) -> NSRect {frameRect}
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class EffectView:NSView {
    let tool:Tool
    let playful:Bool
    let born=Date().timeIntervalSince1970
    override var isFlipped:Bool {true}
    init(tool:Tool,playful:Bool=false) {self.tool=tool;self.playful=playful;super.init(frame:NSRect(x:0,y:0,width:146,height:140))}
    required init?(coder:NSCoder) {fatalError()}
    override func draw(_ dirtyRect:NSRect) {
        let text:String
        switch tool {case .pinch:text="噗叽！";case .slipper:text="啪！";case .vacuum:text="咻——";case .cleaner:text="亮晶晶 ✧";case .poison:text="躺平。"}
        if !playful {paintRect(NSRect(x:23,y:25,width:100,height:32),cream,radius:15,stroke:ink,width:2)
        label(text,35,30,size:16,weight:.heavy,c:tool == .slipper ? orange : moss,width:90)}
        if tool == .poison {drawSpray(in:bounds,elapsed:Date().timeIntervalSince1970-born)} else if tool == .vacuum {
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
        let size: CGFloat = desktopSize(r.kind)
        if let entry=e.entrances[id],now<entry.until {
            let clip=NSBezierPath(rect:bounds);clip.windingRule = .evenOdd
            clip.appendRect(NSRect(x:entry.frame.minX-r.x,y:bounds.height-entry.frame.maxY+r.y,width:entry.frame.width,height:entry.frame.height));clip.addClip()
        }
        let bounce=(r.reactionUntil ?? 0)>now ? sin(((r.reactionUntil ?? now)-now)*32)*4 : 0
        drawBug(in:NSRect(x:(bounds.width-size)/2+bounce,y:bounds.height-size,width:size,height:size),kind:r.kind,phase:r.kind == .catPaw ? now-r.born : now,flying:r.flyingUntil>now,facing:r.vx>=0 ? 1 : -1)
        if (r.carryUntil ?? 0)>now {
            paintRect(NSRect(x:bounds.width/2,y:bounds.height-28,width:28,height:23),cream,radius:3,stroke:ink)
            for y in [8.0,14.0] {line([NSPoint(x:bounds.width/2+5,y:bounds.height-28+y),NSPoint(x:bounds.width/2+23,y:bounds.height-28+y)],moss,1)}
        }
        if r.tauntUntil>now {
            paintRect(NSRect(x:3,y:7,width:140,height:27),cream,radius:12,stroke:ink)
            label(r.flyingUntil>now ? "打不到～我会飞！" : "你以为没有了？",13,11,size:11,weight:.semibold,width:128)
        }
    }
    override func mouseDown(with event:NSEvent) {if event.modifierFlags.contains(.control) {engine?.animalMenu(id,event:event,in:self)}else{engine?.interact(id)}}
    override func rightMouseDown(with event:NSEvent){engine?.animalMenu(id,event:event,in:self)}
    override func otherMouseDown(with event:NSEvent){engine?.interact(id)}
    override func accessibilityPerformPress() -> Bool { engine?.interact(id); return true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.pointingHand) }
}

final class Dashboard: NSView {
    weak var engine:Paradise?
    var tools:[Tool:ActionButton]=[:]
    var pauseButton:ActionButton!
    var quietButton:ActionButton?
    var finderButton:ActionButton?
    override var isFlipped:Bool{true}
    init(engine:Paradise){
        self.engine=engine;super.init(frame:NSRect(x:0,y:0,width:620,height:420))
        func button(_ title:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ action:@escaping ()->Void)->ActionButton {let b=ActionButton(title,frame:NSRect(x:x,y:y,width:w,height:40),action:action);addSubview(b);return b}
        let settings=button("···",548,22,44){[weak engine] in engine?.showOptions()};settings.small=true
        for (i,t) in Tool.allCases.enumerated(){let b=button(t.title,28+CGFloat(i)*114,245,108){[weak engine] in engine?.select(t)};b.small=true;tools[t]=b}
        let feed=button("＋ 喂一点",28,318,132){[weak engine] in engine?.feed()};feed.fillColor=moss;feed.textColor=cream
        _=button("去桌面玩",170,318,132){[weak engine] in engine?.release()}
        _=button("我的小窝",312,318,132){[weak engine] in engine?.showLife()}
        pauseButton=button("歇一会儿",454,318,138){[weak engine] in engine?.togglePause()}
    }
    required init?(coder:NSCoder){fatalError()}
    func refresh(){guard let e=engine else{return};for (t,b) in tools {let owns=e.state.unlocked.contains(t);b.title=t.title+(owns ? "" : " · \(t.cost) ✦");b.fillColor=e.state.tool==t ? moss : color(0xEBECDD);b.textColor=e.state.tool==t ? cream : ink;b.needsDisplay=true};pauseButton.title=e.paused ? "继续玩" : "歇一会儿";needsDisplay=true}
    override func draw(_ dirtyRect:NSRect){guard let e=engine else{return};paintRect(bounds,cream)
        label("旮旯乐园",28,26,size:23,weight:.heavy);label("你的桌面，有几个小住客。",29,59,size:11,c:moss)
        paintRect(NSRect(x:28,y:96,width:564,height:126),color(0xE8ECD9),radius:22)
        label("碰一下，就有回应。",46,119,size:24,weight:.bold)
        label("左键用工具，右键交朋友。",47,158,size:14,c:moss)
        label(e.paused ? "它们在休息" : "路过时把鼠标靠近，它会停下来等你。",47,186,size:11,c:moss)
        drawBug(in:NSRect(x:466,y:98,width:115,height:115),phase:Date().timeIntervalSince1970)
        label("今天拿什么逗它们？",30,226,size:11,c:moss)
        label("✦ \(e.state.progression?.shells ?? 0)",525,226,size:11,weight:.semibold,c:moss)
        label("旮杂会躲，老鼠会抖毛，猫爪会接招。",30,293,size:11,c:moss)
        label(e.message,30,376,size:12,c:moss,width:560)
    }
}

final class Paradise: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var state=GameState()
    var habitat=Habitat()
    var entrances:[UUID:(frame:CGRect,until:Double)]=[:]
    var isTestRun:Bool { CommandLine.arguments.contains("--smoke") || CommandLine.arguments.contains("--render") || CommandLine.arguments.contains("--integration-test") }
    var window:NSWindow!
    var lastLifeRefresh:Double=0
    var reactions:[UUID:PetPanel]=[:]
    var tracePanel:PetPanel?
    var lifeController:LifeController?
    var dashboard:Dashboard!
    var status:NSStatusItem!
    var panels:[UUID:PetPanel]=[:]
    var visits:[UUID:Visit]=[:]
    var nextGold=Date().timeIntervalSince1970+20
    var nextMouse=Date().timeIntervalSince1970
    var nextCat=Date().timeIntervalSince1970
    var nextAppearance=Date().timeIntervalSince1970+8
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
        state.migrateProgression();state.ensureLife();state.life!.focusRemaining=0
        if !isTestRun,let data=try? Data(contentsOf:saveURL.deletingLastPathComponent().appendingPathComponent("habitat.json")),let restored=try? JSONDecoder().decode(Habitat.self,from:data) {habitat=restored;habitat.rate=[0.25,1,3].contains(habitat.rate) ? habitat.rate : 1}
        let menu=NSMenu(); let appItem=NSMenuItem(); menu.addItem(appItem); let appMenu=NSMenu(); appMenu.addItem(withTitle:"关于旮旯乐园",action:#selector(showDashboard),keyEquivalent:""); appMenu.addItem(.separator()); appMenu.addItem(withTitle:"退出旮旯乐园",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); appItem.submenu=appMenu; NSApp.mainMenu=menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:420),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="旮旯乐园 · Gala Paradise"; window.titlebarAppearsTransparent=true; window.backgroundColor=cream; window.isReleasedWhenClosed=false; window.delegate=self
        dashboard=Dashboard(engine:self); window.contentView=dashboard; window.center()
        status=NSStatusBar.system.statusItem(withLength:32)
        status.button?.image=menuPetIcon()
        status.button?.setAccessibilityLabel("旮旯乐园：切换清洁工具")
        rebuildMenu()
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        if state.residents.isEmpty && state.xp==0 { spawn(.adult); spawn(.baby) }
        for r in state.residents where r.live {visits[r.id]=Visit()}
        syncPanels(); showDashboard()
        timer=Timer.scheduledTimer(timeInterval:1.0/30.0,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        if CommandLine.arguments.contains("--render") { DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { self.renderPreview(); NSApp.terminate(nil) } }
        if CommandLine.arguments.contains("--integration-test") { DispatchQueue.main.asyncAfter(deadline:.now()+0.3) { self.integrationTest(); NSApp.terminate(nil) } }
        if CommandLine.arguments.contains("--smoke") { DispatchQueue.main.asyncAfter(deadline:.now()+2) { self.folderBurst(name:"自动验收",at:nil); self.feed(); self.select(.pinch); print("SMOKE: window=\(self.window.isVisible), sprites=\(self.panels.count), xp=\(self.state.xp)"); NSApp.terminate(nil) } }
    }
    func rebuildMenu() {
        let m=NSMenu()
        let heading=NSMenuItem(title:"当前工具："+state.tool.title,action:nil,keyEquivalent:"")
        m.addItem(heading);m.addItem(withTitle:"黄金卵壳："+String(state.progression?.shells ?? 0),action:nil,keyEquivalent:"");m.addItem(withTitle:"新朋友："+(state.progression?.seen.isEmpty == false ? state.progression!.seen.map{$0 == "mouse" ? "老鼠" : "猫爪"}.joined(separator:"、") : "老鼠 3 分钟 / 猫爪 10 分钟"),action:nil,keyEquivalent:"");m.addItem(.separator())
        status.button?.toolTip="旮旯乐园 · 当前："+state.tool.title+" · 点击换工具"
        func item(_ title:String,_ action:Selector,_ key:String="") { let i=NSMenuItem(title:title,action:action,keyEquivalent:key); i.target=self; m.addItem(i) }
        item("我的小窝 · 伙伴 / 纸条 / 成就",#selector(showLife));
        item("打开旮旯乐园",#selector(showDashboard)); item("撒点面包屑  +3",#selector(feed)); item(paused ? "继续桌宠" : "暂停并隐藏桌宠",#selector(togglePause)); item(state.quiet ? "关闭专注模式" : "开启专注模式",#selector(toggleQuiet))
        m.addItem(.separator())
        for t in Tool.allCases { let i=NSMenuItem(title:state.unlocked.contains(t) ? t.title : "\(t.title)（\(t.cost) 金壳兑换）",action:#selector(menuTool(_:)),keyEquivalent:""); i.target=self; i.representedObject=t.rawValue; i.image=NSImage(systemSymbolName:t.glyph,accessibilityDescription:t.title); i.state=state.tool==t ? .on : .off; m.addItem(i) }
        if state.poisoned { item("收起蟑螂药",#selector(removePoison)) }
        m.addItem(.separator())
        let growth=NSMenuItem(title:"生长速度",action:nil,keyEquivalent:"");let rates=NSMenu()
        for (name,rate) in [("慢慢长 · 0.25×",0.25),("正常 · 1×",1.0),("疯狂长 · 3×",3.0)] {let i=NSMenuItem(title:name,action:#selector(changeRate(_:)),keyEquivalent:"");i.target=self;i.representedObject=rate;i.state=habitat.rate==rate ? .on : .off;rates.addItem(i)}
        growth.submenu=rates;m.addItem(growth)
        item("清理游戏痕迹",#selector(scan));item("连接 Finder",#selector(connectFinderMenu));item("试玩文件夹",#selector(tryFolder))
        m.addItem(.separator()); item("退出旮旯乐园",#selector(quit),"q"); status.menu=m
    }
    func showGrowthMenu(){if let menu=status.menu?.items.first(where:{$0.title=="生长速度"})?.submenu {menu.popUp(positioning:nil,at:NSPoint(x:560,y:65),in:dashboard)}}
    @objc func changeRate(_ sender:NSMenuItem) {if let rate=sender.representedObject as? Double {habitat.rate=rate;save();rebuildMenu();tell("生长速度已调整为 "+String(rate)+"×")}}
    @objc func scan() {
        guard state.unlocked.contains(.poison) else {tell("兑换杀虫喷雾后，可使用全局扫描");return}
        let beforeCount=state.residents.count
        let protectedIDs=Set(state.residents.filter{state.protected($0) || (state.life?.safeLeft==true && $0.x < (NSScreen.main?.frame.midX ?? 0))}.map{$0.id})
        state.residents.removeAll{$0.kind != .stain && !$0.friend && !protectedIDs.contains($0.id)};habitat.clean(now:Date().timeIntervalSince1970)
        syncPanels();save();tell("扫描清走 "+String(beforeCount-state.residents.count)+" 个住客／卵，防护 5 分钟；污渍手动擦")
    }
    @objc func menuTool(_ sender:NSMenuItem) { if let raw=sender.representedObject as? String,let t=Tool(rawValue:raw) {select(t)} }
    @objc func showDashboard() { if window.isMiniaturized {window.deminiaturize(nil)};window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); dashboard.refresh() }
    @objc func quit() { NSApp.terminate(nil) }
    func windowDidMiniaturize(_ notification:Notification) {tell("已最小化，点顶部蟑螂图标就能换工具")}
    func windowWillClose(_ notification:Notification) { tell("面板已收起，顶部蟑螂图标可以召回") }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    func applicationWillTerminate(_ notification:Notification) {save(); panels.values.forEach{$0.orderOut(nil)}}
    func tell(_ text:String) { message=text; dashboard?.refresh() }
    func select(_ tool:Tool) {
        guard state.redeem(tool) else {tell("需要 "+String(tool.cost)+" 枚黄金卵壳，捕捉金色旮杂获得"); return}
        state.tool=tool
        if tool == .poison { state.poisoned=true; tell("药已放好。再打开文件夹，看看里面……") } else { tell("已拿起\(tool.title)。点击桌面上的目标") }
        save(); rebuildMenu(); dashboard.refresh()
    }
    @objc func removePoison() { state.poisoned=false; if state.tool == .poison {state.tool = .pinch}; tell("蟑螂药已收起，住客恢复正常出逃"); save(); rebuildMenu() }
    @objc func feed() {
        let now=Date().timeIntervalSince1970
        guard !paused && !state.focusing else {tell("先继续桌宠，再投喂吧"); return}
        guard now-lastFeed>2 else {tell("嚼嚼嚼……稍等两秒再喂"); return}; lastFeed=now
        state.fed+=1; state.gain(3); spawn(.adult)
        if state.fed%2==0 {spawn(.egg)}
        tell("面包屑 +3 生长点。旮杂：还有吗？")
        save(); rebuildMenu(); syncPanels()
    }
    func release() {
        if paused {togglePause()}
        if state.residents.filter({$0.live}).count<4 {spawn(.adult);spawn(.baby)}
        syncPanels(); tell("它们去桌面串门了。顶部蟑螂图标召回面板")
        window.orderOut(nil)
    }
    @objc func togglePause() {
        paused.toggle()
        if paused { pauseStarted=Date().timeIntervalSince1970;panels.values.forEach{$0.orderOut(nil)} } else {
            let now=Date().timeIntervalSince1970, delta=now-pauseStarted
            for i in state.residents.indices {state.residents[i].born+=delta;state.residents[i].flyingUntil+=delta;state.residents[i].tauntUntil+=delta}
            lastHatch+=delta;if emptySince>0 {emptySince+=delta}
            for id in Array(visits.keys) {visits[id]?.deadline+=delta}
            nextAppearance+=delta;nextGold+=delta;nextMouse+=delta;nextCat+=delta
            frameTime=now;syncPanels()
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
        folderBurst(name:name,at:p,frame:window.frame)
    }
    func folderBurst(name:String,at point:NSPoint?,identity:String?=nil,frame:CGRect?=nil) {
        guard !paused && !state.focusing && !state.quiet else {tell("当前已暂停或专注中，文件夹里的住客先不打扰");return}
        let now=Date().timeIntervalSince1970
        guard now-lastFolder>1.2 else {return};lastFolder=now
        state.foldersOpened+=1;state.gain(1)
        let result=habitat.opened(identity ?? "preview:"+name,now:now)
        let firstSide=Int.random(in:0..<4)
        for n in 0..<result.count {
            let side=(n+firstSide)%4
            let edge=frame.map{Habitat.border($0,side:side,fraction:Double.random(in:0.2...0.8))} ?? point
            let previous=state.residents.count
            let inSafe=state.life?.safeLeft==true && (edge?.x ?? 0)<(NSScreen.main?.frame.midX ?? 0)
            spawn(state.poisoned && !inSafe ? .corpse : .adult,at:edge)
            if let frame=frame,state.residents.count>previous,let r=state.residents.last,r.live,let edge=edge {
                entrances[r.id]=(frame,now+2.5)
                visits[r.id]?.target=CGPoint(x:edge.x+(side==0 ? -140 : side==1 ? 140 : 0),y:edge.y+(side==2 ? -140 : side==3 ? 140 : 0))
            }
        }
        if result.eggs && state.residents.filter({$0.kind == .egg}).count<7 {spawn(.egg)}
        tell(state.poisoned ? "「\(name)」一片躺平……但卵没事。" : "「\(name)」开门！三只旮杂溜出来了")
        tell(result.count==0 ? "这个文件夹常被使用或正在防护，没有旮杂出来" : "从「"+name+"」边框溜出 "+String(result.count)+" 只旮杂")
        save();rebuildMenu();syncPanels()
    }
    func interact(_ id:UUID) {
        guard !paused, !state.focusing, visits[id]?.hidden != true else{return}
        if let r=state.residents.first(where:{$0.id==id}),r.live,state.life?.safeLeft==true,r.x < (visits[id]?.screen.midX ?? NSScreen.main?.frame.midX ?? 0) {let msg=state.playfulUse(state.tool,on:id,now:Date().timeIntervalSince1970);tell(msg);showReaction(msg,for:r);showEffect(state.tool,at:NSPoint(x:r.x,y:r.y),playful:true);save();syncPanels();return}
        let old=state.unlocked.count
        let before=state.residents.first{$0.id==id}
        let msg=state.use(state.tool,on:id,now:Date().timeIntervalSince1970,flightRoll:Double.random(in:0...1))
        if state.unlocked.count>old {tell(msg+" · 新工具解锁！")} else {tell(msg)}
        if let index=state.residents.firstIndex(where:{$0.id==id}),!state.residents[index].live {visits.removeValue(forKey:id);entrances.removeValue(forKey:id)}
        if before?.kind == .gold && state.residents.first(where:{$0.id==id})?.live != true {tell("获得 2 枚黄金卵壳 ✦ 点击锁定工具可兑换")}
        if let before=before {
            let after=state.residents.first{$0.id==id}
            showReaction(message,for:before)
            if before.friend || state.protected(before) || state.tool == .poison || after == nil || (before.live && after?.live == false) {showEffect(state.tool,at:NSPoint(x:before.x,y:before.y),playful:before.friend || state.protected(before))}
        }
        save();syncPanels();rebuildMenu()
    }
    func showEffect(_ tool:Tool,at point:NSPoint,playful:Bool=false) {
        guard !isTestRun else{return}
        let panel=PetPanel(contentRect:NSRect(x:point.x,y:point.y+30,width:146,height:140),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.ignoresMouseEvents=true;panel.level = .floating;panel.isReleasedWhenClosed=false;panel.hidesOnDeactivate=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        panel.contentView=EffectView(tool:tool,playful:playful);panel.orderFrontRegardless()
        if tool == .poison {
            let timer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak panel] timer in guard let p=panel else{timer.invalidate();return};p.contentView?.needsDisplay=true}
            DispatchQueue.main.asyncAfter(deadline:.now()+1.15){timer.invalidate();panel.close()}
            return
        }
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
        else if let p=point { x=p.x; y=p.y }
        let now=Date().timeIntervalSince1970
        var r=Resident(kind:kind,x:x,y:y,born:now,vx:Double.random(in:25...65)*(Bool.random() ? 1 : -1),vy:Double.random(in:-30...30))
        if taunt {r.tauntUntil=now+4}
        state.residents.append(r)
        if r.live {
            visits[r.id]=Visit()
            if point != nil || visibleLiveCount<1 {beginVisit(r.id,now:now,from:point)}
        }
    }
    var visibleLiveCount:Int {state.residents.filter{$0.live && visits[$0.id]?.hidden == false}.count}
    func beginVisit(_ id:UUID,now:Double,from point:NSPoint?=nil) {
        guard let i=state.residents.firstIndex(where:{$0.id==id}),let screen=NSScreen.screens.randomElement() else{return}
        let frame: CGRect
        if let p=point {frame=(NSScreen.screens.first{$0.frame.contains(p)} ?? screen).frame} else {frame=screen.frame}
        let edge=Int.random(in:0..<4)
        let start=point ?? Visit.edgePoint(edge,in:frame,fraction:Double.random(in:0.18...0.82),kind:state.residents[i].kind)
        state.residents[i].x=start.x;state.residents[i].y=start.y
        // Cross a short stretch of the current desktop, then slip back out of view.
        let target=CGPoint(x:frame.minX+frame.width*Double.random(in:0.25...0.75)-73,y:frame.minY+frame.height*Double.random(in:0.2...0.7)-35)
        visits[id]=Visit(hidden:false,exiting:false,deadline:now+Double.random(in:9...16),target:target,screen:frame)
    }
    func advanceVisits(_ now:Double,_ dt:Double) {
        var changed=false
        for i in state.residents.indices where state.residents[i].live {
            let id=state.residents[i].id
            if state.residents[i].kind == .baby && now-state.residents[i].born>120 && !state.quiet {state.residents[i].kind = .adult}
            guard var visit=visits[id],!visit.hidden else {continue}
            let resident=state.residents[i]
            let size=desktopSize(resident.kind);let near=NSRect(x:resident.x+(petCanvas(resident.kind).width-size)/2-10,y:resident.y-5,width:size+20,height:size+15)
            if near.contains(NSEvent.mouseLocation) {state.residents[i].holdUntil=now+0.3}
            if !resident.friend && !state.protected(resident) && now < (state.life?.guardUntil ?? 0) && resident.x>=visit.screen.midX {visits[id]=Visit();changed=true;continue}
            if !resident.friend,(state.life?.bonds[id.uuidString.lowercased()]?.fear ?? 0)>0,hypot(NSEvent.mouseLocation.x-resident.x,NSEvent.mouseLocation.y-resident.y)<120 {visit.exiting=true;visit.target=Visit.nearestExit(from:CGPoint(x:resident.x,y:resident.y),in:visit.screen,kind:resident.kind)}
            let speed=(state.residents[i].kind == .mouse ? 145.0 : state.residents[i].kind == .catPaw ? 18.0 : state.residents[i].flyingUntil>now ? 190.0 : 58.0)*(state.quiet ? 0.4 : 1)
            visit.advance(&state.residents[i],now:now,dt:dt,speed:speed)
            visits[id]=visit
            if visit.hidden {nextAppearance=now+Double.random(in:22...45);changed=true}
            if state.residents[i].kind == .baby && now-state.residents[i].born>120 && !state.quiet {state.residents[i].kind = .adult}
        }
        if !state.quiet && now>=habitat.cleanUntil && visibleLiveCount==0 && now>=nextAppearance {
            if let r=state.residents.filter({$0.live && !$0.friend}).randomElement() {beginVisit(r.id,now:now);changed=true}
            nextAppearance=now+Double.random(in:22...45)
        }
        let known=Set(state.life?.bonds.keys.map{$0} ?? [])
        state.residents.removeAll{$0.friend && visits[$0.id]?.hidden == true && !known.contains($0.id.uuidString.lowercased())}
        if changed {syncPanels()}
    }
    func syncPanels() {
        let ids=Set(state.residents.map{$0.id})
        for id in Array(panels.keys) where !ids.contains(id) {panels[id]?.close();panels.removeValue(forKey:id);visits.removeValue(forKey:id);entrances.removeValue(forKey:id)}
        for r in state.residents where panels[r.id]==nil {
            let p=PetPanel(contentRect:NSRect(x:r.x,y:r.y,width:petCanvas(r.kind).width,height:petCanvas(r.kind).height),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.ignoresMouseEvents=true;p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=false;p.level = .floating;p.isReleasedWhenClosed=false;p.hidesOnDeactivate=false
            p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle];p.isMovableByWindowBackground=false
            p.contentView=PetView(id:r.id,engine:self);panels[r.id]=p
        }
        for r in state.residents {
            panels[r.id]?.setFrameOrigin(NSPoint(x:r.x,y:r.y))
            if paused || state.focusing || (r.live && visits[r.id]?.hidden != false) {panels[r.id]?.orderOut(nil)}
            else if panels[r.id]?.isVisible != true {panels[r.id]?.orderFrontRegardless()}
        }
        dashboard?.refresh();syncTrace()
    }
    @objc func screenChanged() {
        guard let f=NSScreen.main?.visibleFrame else{return}
        for i in state.residents.indices {
            if state.residents[i].live {visits[state.residents[i].id]=Visit()}
            else {state.residents[i].x=min(max(state.residents[i].x,f.minX),f.maxX-146);state.residents[i].y=min(max(state.residents[i].y,f.minY),f.maxY-140)}
        }
        nextAppearance=Date().timeIntervalSince1970+8
        if dashboard != nil {syncPanels()}
    }
    @objc func tick() {
        let now=Date().timeIntervalSince1970;let dt=min(0.1,now-frameTime);frameTime=now
        state.ensureLife()
        if state.focusing {for i in state.residents.indices {state.residents[i].born+=dt};lastHatch+=dt}
        if state.life!.tick((paused || state.quiet) && !state.focusing ? 0 : dt,now) {tell("专注完成！大家等你回来");nextAppearance=now+20;nextGold=now+30;nextMouse=now+60;nextCat=now+90;syncPanels()}
        syncTrace()
        if now-lastLifeRefresh>=1 {lastLifeRefresh=now;if lifeController?.window?.isVisible==true {lifeController?.refresh()}}
        guard !paused && !state.focusing else{return};tickCount+=1
        if !state.quiet {for i in state.residents.indices where state.residents[i].kind == .egg || state.residents[i].kind == .baby {state.residents[i].born-=dt*(habitat.rate-1)}}
        state.progression?.played+=dt
        if !state.quiet {encounters(now)}
        advanceVisits(now,dt)
        for i in state.residents.indices {
            let r=state.residents[i]
            if r.live && visits[r.id]?.hidden == false,let panel=panels[r.id],NSScreen.screens.contains(where:{$0.frame.intersects(panel.frame)}) {state.life?.observe(r,now)}
            if r.live && visits[r.id]?.hidden != false {continue}
            panels[r.id]?.setFrameOrigin(NSPoint(x:r.x,y:r.y));panels[r.id]?.contentView?.needsDisplay=true
            // Only the visible character captures clicks; the rest of the desktop remains usable.
            let size:Double = desktopSize(r.kind)
            let hit=NSRect(x:r.x+(petCanvas(r.kind).width-size)/2-8,y:r.y,width:size+16,height:size)
            panels[r.id]?.ignoresMouseEvents = !hit.contains(NSEvent.mouseLocation) || (entrances[r.id].map{now<$0.until && $0.frame.contains(NSEvent.mouseLocation)} ?? false)
        }
        if tickCount%30==0 {
            if !state.quiet {ecology(now);checkFinder()}
            dashboard.refresh();if lifeController?.window?.isVisible==true {lifeController?.refresh()}
        }
        if tickCount%300==0 {save()}
    }
    func encounters(_ now:Double){
        guard now>=habitat.cleanUntil else{return}
        if now>=nextGold {
            nextGold=now+Double.random(in:45...90)
            if let r=state.residents.first(where:{$0.kind == .gold && visits[$0.id]?.hidden == true && !(state.life?.goldPaid.contains($0.id.uuidString.lowercased()) ?? false)}) {beginVisit(r.id,now:now)}
            else if state.residents.filter({$0.kind == .gold && !(state.life?.goldPaid.contains($0.id.uuidString.lowercased()) ?? false)}).count<2 {spawn(.gold,taunt:true);if let r=state.residents.last,r.kind == .gold {beginVisit(r.id,now:now)}}
        }
        let played=state.progression?.played ?? 0
        if played>=180 && now>=nextMouse {
            nextMouse=now+Double.random(in:120...240)
            if state.residents.filter({$0.kind == .mouse && visits[$0.id]?.hidden == false}).count<2 {spawnFriend(.mouse,now:now)}
        }
        if played>=600 && now>=nextCat {
            nextCat=now+Double.random(in:240...420)
            if !state.residents.contains(where:{$0.kind == .catPaw && visits[$0.id]?.hidden == false}) {spawnFriend(.catPaw,now:now)}
        }
    }
    func spawnFriend(_ kind:BugKind,now:Double){
        if let known=state.residents.first(where:{$0.kind==kind && visits[$0.id]?.hidden != false}) {summon(known.id,now);return}
        let before=state.residents.count;spawn(kind)
        guard state.residents.count>before,let r=state.residents.last,let screen=NSScreen.main else{return}
        beginVisit(r.id,now:now)
        let f=screen.frame
        if kind == .mouse {state.residents[state.residents.count-1].x=f.minX-petCanvas(kind).width;state.residents[state.residents.count-1].y=f.minY+120;visits[r.id]?.target=CGPoint(x:f.maxX,y:f.minY+120);visits[r.id]?.deadline=now+14}
        else {state.residents[state.residents.count-1].x=f.maxX-220;state.residents[state.residents.count-1].y=f.minY+170;state.residents[state.residents.count-1].born=now;visits[r.id]?.screen=f}
        if state.progression?.seen.contains(kind.rawValue) == false {state.progression?.seen.append(kind.rawValue);tell(kind == .mouse ? "新朋友解锁：路过的小老鼠" : "新朋友解锁：一只探进来的猫爪")}
        syncPanels();save()
    }
    func ecology(_ now:Double) {
        guard now>=habitat.cleanUntil else{return}
        if let i=state.residents.firstIndex(where:{$0.kind == .egg && now-$0.born>55}),state.residents.count<maxResidents {
            state.residents.remove(at:i)
            spawn(.baby,taunt:true);spawn(.baby)
            tell("角落的卵孵化了。小旮杂：没想到吧？");syncPanels()
        }
        if state.residents.contains(where:{$0.live && !$0.friend}) && now-lastHatch>75/habitat.rate {
            lastHatch=now
            if state.residents.filter({$0.kind == .egg}).count<5 {spawn(.egg);syncPanels()}
        }
        if !state.residents.contains(where:{$0.live && !$0.friend}) {
            if emptySince==0 {emptySince=now}
            if now-emptySince>24 {spawn(.baby,taunt:true);emptySince=0;tell("漏网之鱼：你以为电脑干净了？");syncPanels()}
        } else {emptySince=0}

    }
    func checkFinder() {
        guard AXIsProcessTrusted(), let front=NSWorkspace.shared.frontmostApplication,front.bundleIdentifier=="com.apple.finder" else{lastFinder="";return}
        let app=AXUIElementCreateApplication(front.processIdentifier)
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,kAXFocusedWindowAttribute as CFString,&value) == .success,let value=value,CFGetTypeID(value)==AXUIElementGetTypeID() else{return}
        let win=unsafeBitCast(value,to:AXUIElement.self)
        var titleValue:CFTypeRef?,docValue:CFTypeRef?,positionValue:CFTypeRef?,sizeValue:CFTypeRef?
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
        var windowFrame:CGRect?=nil
        if AXUIElementCopyAttributeValue(win,kAXSizeAttribute as CFString,&sizeValue) == .success,let sizeValue=sizeValue,CFGetTypeID(sizeValue)==AXValueGetTypeID(),let pos=positionValue,CFGetTypeID(pos)==AXValueGetTypeID() {
            var size=CGSize.zero;var origin=CGPoint.zero
            if AXValueGetValue(unsafeBitCast(sizeValue,to:AXValue.self),.cgSize,&size) && AXValueGetValue(unsafeBitCast(pos,to:AXValue.self),.cgPoint,&origin) {windowFrame=CGRect(x:origin.x,y:(NSScreen.screens.first?.frame.maxY ?? 900)-origin.y-size.height,width:size.width,height:size.height)}
        }
        folderBurst(name:title,at:point,identity:(docValue as? String) ?? title,frame:windowFrame)
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
        let desktop=NSImage(size:NSSize(width:520,height:180))
        desktop.lockFocusFlipped(true)
        paintRect(NSRect(x:0,y:0,width:520,height:180),cream)
        label("桌面住客 · 缩小后的实际尺寸",20,15,size:14,weight:.semibold)
        drawBug(in:NSRect(x:40,y:65,width:68,height:68),phase:0)
        drawBug(in:NSRect(x:170,y:88,width:45,height:45),kind:.baby,phase:0)
        menuPetIcon().draw(in:NSRect(x:330,y:95,width:23,height:22))
        label("成虫 68 pt",36,140,size:12);label("幼体 45 pt",157,140,size:12);label("菜单栏图标",310,140,size:12)
        desktop.unlockFocus()
        if let tiff=desktop.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff) {try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/desktop-scale.png"))}
        let friends=NSImage(size:NSSize(width:1000,height:260));friends.lockFocusFlipped(true)
        paintRect(NSRect(x:0,y:0,width:1000,height:260),cream)
        drawBug(in:NSRect(x:20,y:20,width:180,height:180),kind:.gold)
        drawFriend(in:NSRect(x:230,y:0,width:230,height:230),cat:false,phase:0)
        drawFriend(in:NSRect(x:490,y:15,width:230,height:210),cat:true,phase:3)
        let shift=AffineTransform(translationByX:790,byY:40);(shift as NSAffineTransform).concat();drawSpray(in:NSRect(x:0,y:0,width:146,height:140));let undo=AffineTransform(translationByX:-790,byY:-40);(undo as NSAffineTransform).concat()
        for (i,text) in ["黄金旮杂 · +2 金壳","小老鼠 · 3 分钟","探进来的猫爪 · 10 分钟","手持喷雾 · 泡沫"].enumerated(){label(text,CGFloat(i)*250+30,227,size:14,weight:.semibold)}
        friends.unlockFocus()
        if let tiff=friends.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff){try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/new-friends.png"))}
        let mouse=NSImage(size:NSSize(width:600,height:300));mouse.lockFocusFlipped(true)
        paintRect(NSRect(x:0,y:0,width:600,height:300),cream)
        label("新朋友 · 圆耳鼠",30,22,size:22,weight:.bold)
        drawFriend(in:NSRect(x:40,y:60,width:240,height:240),cat:false,phase:0)
        drawBug(in:NSRect(x:350,y:130,width:68,height:68),phase:0)
        drawFriend(in:NSRect(x:425,y:55,width:170,height:170),cat:false,phase:0)
        label("同画风 · 桌面尺寸对比",340,245,size:14,weight:.semibold)
        mouse.unlockFocus()
        if let tiff=mouse.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff){try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/mouse-preview.png"))}
        showLife()
        if let view=lifeController?.window?.contentView,let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) {view.cacheDisplay(in:view.bounds,to:bitmap);try? bitmap.representation(using:.png,properties:[:])?.write(to:root.appendingPathComponent("Resources/life-preview.png"))}
        print("RENDER: dashboard, characters, desktop sizes, new friends and resident handbook exported")
    }
    func integrationTest() {
        timer?.invalidate()
        state=GameState();state.progression=nil;syncPanels()
        for tool in Tool.allCases {precondition(dashboard.tools[tool]!.title.contains(tool.title))}
        dashboard.tools[.slipper]!.performClick(nil)
        precondition(state.tool == .pinch)
        folderBurst(name:"测试文件夹",at:NSPoint(x:200,y:200))
        precondition(state.residents.filter{$0.live}.count==2)
        precondition(state.residents.filter{$0.kind == .egg}.count==1)
        precondition(panels.count==3)
        state.xp=28;state.progression=nil;dashboard.tools[.poison]!.performClick(nil);lastFolder=0
        precondition(state.tool == .poison && state.poisoned)
        folderBurst(name:"投药测试",at:nil)
        precondition(state.residents.filter{$0.kind == .corpse}.count==2)
        precondition(state.residents.filter{$0.kind == .egg}.count==2)
        let now=Date().timeIntervalSince1970
        for i in state.residents.indices where state.residents[i].kind == .egg {state.residents[i].born=now-60}
        lastHatch=now;ecology(now)
        precondition(state.residents.filter{$0.kind == .baby}.count==2)
        precondition(state.residents.filter{$0.kind == .egg}.count==1)
        state.tool = .vacuum
        for id in state.residents.map({$0.id}) {if visits[id]?.hidden == true {beginVisit(id,now:now,from:NSPoint(x:200,y:200))};interact(id)}
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
        precondition(status.button?.image?.isTemplate == true)
        window.miniaturize(nil)
        let toolItem=status.menu!.items.first{($0.representedObject as? String)==Tool.cleaner.rawValue}!
        menuTool(toolItem)
        precondition(state.tool == .cleaner)
        precondition(status.menu!.items.first{($0.representedObject as? String)==Tool.cleaner.rawValue}?.state == .on)
        showDashboard()
        precondition(!window.isMiniaturized && window.isVisible)
        for r in state.residents where r.live {visits[r.id]=Visit()}
        nextAppearance=now+30;syncPanels()
        precondition(panels.values.allSatisfy{!$0.isVisible})
        advanceVisits(now+10,1)
        precondition(visibleLiveCount==0)
        advanceVisits(now+31,0)
        precondition(visibleLiveCount==1)
        let guest=state.residents.first{visits[$0.id]?.hidden == false}!
        precondition(panels[guest.id]?.isVisible == true)
        let actual=panels[guest.id]!.frame.origin
        precondition(abs(actual.x-guest.x)<=1 && abs(actual.y-guest.y)<=1,"Offscreen panel was constrained")
        var departure=now+32
        for step in 0..<1500 {
            departure=now+32+Double(step)/30
            advanceVisits(departure,1.0/30)
            if visibleLiveCount==0 {break}
        }
        precondition(visibleLiveCount==0)
        advanceVisits(departure+10,1)
        precondition(visibleLiveCount==0)
        precondition(panels.values.allSatisfy{!$0.isVisible})
        togglePause();togglePause()
        precondition(panels.values.allSatisfy{!$0.isVisible})
        let rates=status.menu!.items.first{$0.title=="生长速度"}!.submenu!
        changeRate(rates.items.last!);precondition(habitat.rate==3)
        state.residents=[Resident(kind:.stain,x:200,y:200,born:now),Resident(kind:.egg,x:100,y:100,born:now)]
        scan();precondition(state.residents.count==1 && state.residents[0].kind == .stain)
        ecology(Date().timeIntervalSince1970+2);precondition(state.residents.count==1)
        habitat.cleanUntil=0;state.residents=[];state.progression=Progression();state.progression!.played=179;nextGold=now+10000;nextMouse=0;nextCat=0
        encounters(now);precondition(!state.residents.contains(where:{$0.friend}))
        state.progression!.played=180;encounters(now+1);precondition(state.residents.filter{$0.kind == .mouse}.count==1)
        state.progression!.played=600;encounters(now+2);precondition(state.residents.filter{$0.kind == .catPaw}.count==1)
        encounters(now+3);precondition(state.residents.filter{$0.friend}.count==2)
        precondition(state.progression!.seen.count==2)
        syncPanels()
        let mouseResident=state.residents.first{$0.kind == .mouse}!
        precondition(panels[mouseResident.id]!.contentView!.bounds.size == petCanvas(.mouse))
        precondition(desktopSize(.mouse) < panels[mouseResident.id]!.frame.width)
        state.ensureLife()
        let beforeX=state.residents.first{$0.id==mouseResident.id}!.x
        let choice=NSMenuItem();choice.representedObject=[mouseResident.id.uuidString,"pet"];animalChoice(choice)
        precondition(state.residents.first{$0.id==mouseResident.id}!.x==beforeX)
        precondition(state.life!.cards["touch.mouse"] != nil)
        print("PASS: right-click action stays on the same mouse and records interaction")
        lifeAction("name",id:mouseResident.id,text:"圆耳",note:nil)
        precondition(state.protected(state.residents.first{$0.id==mouseResident.id}!))
        showLife();precondition(lifeController?.window?.isVisible==true)
        lifeAction("focus",id:nil,text:"",note:nil,minutes:1)
        precondition(state.focusing && panels.values.allSatisfy{!$0.isVisible})
        state.life!.focusRemaining=0.001;frameTime=Date().timeIntervalSince1970-0.02;tick()
        precondition(state.life!.cards["focus.first"] != nil)
        lifeController?.window?.orderOut(nil)
        print("PASS: native handbook, naming protection, focus hides panels and completion card")
        print("PASS: mouse canvas fits enlarged art")
        print("PASS: mouse/cat playtime discovery and encounter cooldowns")
        print("PASS: growth menu and scan protection preserve manual stain cleanup")
        print("PASS: menu icon/tool selection while minimized, restore, hidden population, blank interval, edge visit, exit, pause preserves hiding")
        print("PASS: native window/panels, folder burst, poison spares eggs, hatch, vacuum removal, survivor, pause, focus, cap")
    }
    func load() {
        if isTestRun {return}
        guard let data=try? Data(contentsOf:saveURL) else{return}
        do {state=try JSONDecoder().decode(GameState.self,from:data);if state.life==nil {let backup=saveURL.deletingLastPathComponent().appendingPathComponent("save.before-1.5.json");if !FileManager.default.fileExists(atPath:backup.path){try? data.write(to:backup,options:.atomic)}};if state.progression==nil {let backup=saveURL.deletingLastPathComponent().appendingPathComponent("save.before-1.4.json");if !FileManager.default.fileExists(atPath:backup.path){try? data.write(to:backup,options:.atomic)}};state.residents=Array(state.residents.prefix(maxResidents)); state.migrateProgression();screenChanged()} catch {message="存档暂时无法读取，本次从新乐园开始"}
        lastHatch=Date().timeIntervalSince1970
    }
    func save() {
        if isTestRun {return}
        state.lastSaved=Date().timeIntervalSince1970
        do {try FileManager.default.createDirectory(at:saveURL.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(state).write(to:saveURL,options:.atomic);try JSONEncoder().encode(habitat).write(to:saveURL.deletingLastPathComponent().appendingPathComponent("habitat.json"),options:.atomic)} catch {message="存档写入失败：\(error.localizedDescription)"}
    }
}
