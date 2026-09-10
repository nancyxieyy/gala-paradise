import AppKit
final class LifeView:NSView {override var isFlipped:Bool{true};override func draw(_ dirtyRect:NSRect){cream.setFill();bounds.fill()}}
final class LifeCardsView:NSView {
 var life=Life();var message=""
 override var isFlipped:Bool{true}
 override func draw(_ dirtyRect:NSRect){
  cream.setFill();bounds.fill();label(message,10,8,size:12,width:730)
  label("脚印："+(life.traceReady ? "发现碎屑，可追踪" : "等待新的痕迹")+" · 安全窝："+(life.safeLeft ? "开启" : "关闭")+" · 专注剩余 "+String(Int(life.focusRemaining))+" 秒",10,48,size:12,width:730)
  for (i,a) in Life.achievements.enumerated(){let x=CGFloat(i%2)*375+5,y=CGFloat(i/2)*79+83;let earned=life.cards[a.0]
   paintRect(NSRect(x:x,y:y,width:365,height:69),earned == nil ? color(0xECEBDF) : color(0xDDE6CD),radius:12)
   label((earned == nil ? "○ " : "✦ ")+a.1,x+12,y+10,size:14,weight:.semibold,width:339)
   label(earned.map{Date(timeIntervalSince1970:$0).formatted(date:.abbreviated,time:.shortened)} ?? "尚未发现 · 不必集齐每条支线",x+12,y+39,size:11,width:339)
  }
 }
}

final class LifeController:NSWindowController {
 weak var engine:Paradise?
 let guests=NSPopUpButton();let input=NSTextField();let notes=NSPopUpButton();let minutes=NSTextField(string:"25");let report=NSTextView();let cards=LifeCardsView()
 var ids:[UUID]=[];var noteIDs:[String]=[]
 init(_ engine:Paradise){
  self.engine=engine
  let w=NSWindow(contentRect:NSRect(x:0,y:0,width:830,height:690),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
  super.init(window:w);w.title="住客手册 · 关系 / 纸条 / 支线 / 成就";w.isReleasedWhenClosed=false;w.backgroundColor=cream
  let v=LifeView(frame:NSRect(x:0,y:0,width:830,height:690));w.contentView=v
  func title(_ text:String,_ y:CGFloat){let t=NSTextField(labelWithString:text);t.frame=NSRect(x:22,y:y,width:790,height:24);t.font = .systemFont(ofSize:15,weight:.semibold);v.addSubview(t)}
  func button(_ text:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ action:@escaping ()->Void){v.addSubview(ActionButton(text,frame:NSRect(x:x,y:y,width:width,height:32),action:action))}
  title("01 / 熟悉的住客 · 信任 6 可结为伙伴，每 20 秒一次有效互动",18)
  guests.frame=NSRect(x:22,y:48,width:650,height:28);v.addSubview(guests);button("刷新",686,46,120){[weak self] in self?.refresh()}
  input.frame=NSRect(x:22,y:86,width:784,height:28);input.placeholderString="在这里输入名字、纸条、链接或领养码（只处理你主动提交的内容）";v.addSubview(input)
  let actions=[("召回","recall"),("摸一摸","pet"),("喂一口","feed"),("取名字","name"),("成为伙伴","bond"),("友好取金壳","gold")]
  for (i,a) in actions.enumerated(){button(a.0,22+CGFloat(i)*132,128,124){[weak self] in self?.perform(a.1)}}
  title("02 / 小窝收纳 · 动物躲起来也能取回，复制不会删除",179)
  notes.frame=NSRect(x:22,y:210,width:520,height:28);v.addSubview(notes)
  button("收好输入内容",550,208,125){[weak self] in self?.perform("stash")};button("复制取回",682,208,124){[weak self] in self?.perform("return")}
  button("标记 / 取消完成",22,247,160){[weak self] in self?.perform("done")};button("删除选中纸条",190,247,160){[weak self] in self?.perform("delete")}
  title("03 / 桌面支线 · 安全窝位于左半屏，巡逻位于右半屏",296)
  button("查看脚印 / 探索",22,326,153){[weak self] in self?.perform("explore")};button("开启 / 关闭安全窝",182,326,174){[weak self] in self?.perform("safe")}
  button("请伙伴巡逻",365,326,140){[weak self] in self?.perform("patrol")};button("安排共居",514,326,132){[weak self] in self?.perform("coexist")};button("生成领养码",655,326,151){[weak self] in self?.perform("share")}
  button("接收输入的领养码",22,369,175){[weak self] in self?.perform("adopt")}
  minutes.frame=NSRect(x:215,y:371,width:50,height:28);v.addSubview(minutes)
  button("分钟 · 开始专注",274,369,150){[weak self] in self?.perform("focus")};button("结束本次计时",434,369,145){[weak self] in self?.perform("cancel")}
  title("04 / 成就卡册与动态 · 只记录已完成的事件",423)
  let scroll=NSScrollView(frame:NSRect(x:22,y:453,width:784,height:212));scroll.hasVerticalScroller=true;scroll.documentView=cards;cards.frame=NSRect(x:0,y:0,width:760,height:970);cards.setAccessibilityElement(true);cards.setAccessibilityLabel("成就卡册");v.addSubview(scroll)
  w.center();refresh()
 }
 required init?(coder:NSCoder){fatalError()}
 func refresh(){guard let e=engine else{return};e.state.ensureLife();let life=e.state.life!;let selected=guests.indexOfSelectedItem;let old=ids.indices.contains(selected) ? ids[selected] : nil
  ids=e.state.residents.filter{$0.live && (life.bonds[$0.id.uuidString.lowercased()] != nil || e.visits[$0.id]?.hidden == false)}.map{$0.id}
  guests.removeAllItems();for id in ids {let r=e.state.residents.first{$0.id==id}!;let b=life.bonds[id.uuidString.lowercased()];guests.addItem(withTitle:"\(b?.name.isEmpty == false ? b!.name : r.kind == .mouse ? "小老鼠" : r.kind == .catPaw ? "猫咪" : "旮杂") · \(id.uuidString.prefix(4)) · 信任 \(b?.trust ?? 0) / 警惕 \(b?.fear ?? 0) · \(b?.protected == true ? "受保护" : "访客")")};if let old=old,let i=ids.firstIndex(of:old){guests.selectItem(at:i)}
  if ids.isEmpty {guests.addItem(withTitle:"尚未遇见住客 · 回主面板撒点面包屑，或等待来访")}
  let oldNote=notes.indexOfSelectedItem;noteIDs=life.notes.map{$0.id};notes.removeAllItems();for n in life.notes {notes.addItem(withTitle:(n.done ? "✓ " : "○ ")+String(n.text.prefix(45)).replacingOccurrences(of:"\n",with:" "))};if oldNote>=0 && oldNote<noteIDs.count{notes.selectItem(at:oldNote)}
  if noteIDs.isEmpty {notes.addItem(withTitle:"暂无纸条 · 输入内容后点收好")}
  cards.life=life;cards.message=e.message;cards.needsDisplay=true
  report.string="\(e.message)\n\n脚印：\(life.traceReady ? "发现了碎屑，点探索追踪" : "等待住客留下痕迹")  · 安全窝：\(life.safeLeft ? "开启" : "关闭")  · 专注剩余：\(Int(life.focusRemaining)) 秒\n\n"+Life.achievements.map{key,name in life.cards[key].map{"✓ \(name) · "+Date(timeIntervalSince1970:$0).formatted(date:.abbreviated,time:.shortened)} ?? "○ \(name)"}.joined(separator:"\n")
  cards.setAccessibilityValue(report.string)
 }
 func perform(_ action:String){guard let e=engine else{return};let i=guests.indexOfSelectedItem;let id=ids.indices.contains(i) ? ids[i] : nil;let n=notes.indexOfSelectedItem;let note=noteIDs.indices.contains(n) ? noteIDs[n] : nil
  e.lifeAction(action,id:id,text:input.stringValue,note:note,minutes:Double(minutes.stringValue) ?? 25);refresh()
 }
}
extension Paradise {
 @objc func showLife(){if lifeController==nil {lifeController=LifeController(self)};lifeController?.refresh();lifeController?.showWindow(nil);lifeController?.window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
 func summon(_ id:UUID,_ now:Double){
  guard !paused && !state.focusing,let i=state.residents.firstIndex(where:{$0.id==id}),let f=NSScreen.main?.frame else{return}
  let kind=state.residents[i].kind
  state.residents[i].x=kind == .catPaw ? f.maxX-220 : f.midX-80;state.residents[i].y=f.minY+170
  if kind == .catPaw {state.residents[i].born=now-2}
  visits[id]=Visit(hidden:false,exiting:false,deadline:now+8,target:CGPoint(x:state.residents[i].x+80,y:state.residents[i].y),screen:f)
  let observed=state.residents[i];state.life?.observe(observed,now);syncPanels()
 }
 func lifeAction(_ action:String,id:UUID?,text:String,note:String?,minutes:Double=25){
  state.ensureLife();let now=Date().timeIntervalSince1970
  let administrative=["stash","return","done","delete","share","cancel"]
  if (paused || state.focusing) && !administrative.contains(action) {tell("先结束专注或继续桌宠，再进行动物互动");return}
  var result=""
  switch action {
  case "stash":
   let count=state.life!.notes.count;result=state.life!.stash(text,now)
   if state.life!.notes.count>count,!state.focusing,!paused,let id=id,let i=state.residents.firstIndex(where:{$0.id==id}) {summon(id,now);state.residents[i].carryUntil=now+4}
  case "return","done","delete":
   if let note=note,let i=state.life!.notes.firstIndex(where:{$0.id==note}) {
    if action=="return" {NSPasteboard.general.clearContents();NSPasteboard.general.setString(state.life!.notes[i].text,forType:.string);state.life!.award("stash.return",now);result="已复制纸条，原内容仍保留"}
    if action=="done" {state.life!.notes[i].done.toggle();result="待办状态已更新"}
    if action=="delete" {state.life!.notes.remove(at:i);result="已删除选中的纸条"}
   } else {result="先选一条纸条"}
  case "focus":
   state.life!.focusRemaining=max(1,min(120,minutes.isFinite ? minutes : 25))*60
   for r in state.residents where r.live {visits[r.id]=Visit()};result="专注开始，大家回窝了；关闭程序不会自动完成计时"
  case "cancel":state.life!.focusRemaining=0;nextAppearance=now+20;nextGold=now+30;nextMouse=now+60;nextCat=now+90;result="计时已结束，不扣好感"
  case "safe":state.life!.safeLeft.toggle();result="左半屏安全窝已"+(state.life!.safeLeft ? "开启" : "关闭")
  case "explore":
   guard state.life!.traceReady else{tell("还没有新脚印，稍后再来看看");return}
   guard state.residents.count<maxResidents else{tell("住客已满，脚印会保留");return}
   state.life!.traceReady=false;state.life!.award("trace.first",now);state.life!.award("nest.first",now)
   spawn(.gold,at:NSScreen.main.map{NSPoint(x:$0.frame.midX,y:$0.frame.midY)});result="顺着金色碎屑找到一处小窝，试着与住客交朋友"
  case "coexist":
   let partners=state.life!.bonds.filter{$0.value.partner};let species=Set(partners.values.map{$0.kind=="mouse" ? "mouse" : $0.kind=="catPaw" ? "cat" : "roach"})
   guard species.count>=2 else{tell("先认识至少两种伙伴，再安排大家共居");return}
   state.life!.safeLeft=true
   // Shared home is established; visits remain staggered so no chase interrupts it.
   let guests=state.residents.filter{state.life!.bonds[$0.id.uuidString.lowercased()]?.partner==true}
   var seen=Set<String>()
   for r in guests {let kind=r.kind == .mouse ? "mouse" : r.kind == .catPaw ? "cat" : "roach";if seen.insert(kind).inserted {summon(r.id,now);if let i=state.residents.firstIndex(where:{$0.id==r.id}),let f=NSScreen.main?.frame {state.residents[i].x=kind=="roach" ? f.minX+60 : f.maxX-petCanvas(r.kind).width-20;state.residents[i].y=f.minY+(kind=="mouse" ? 310 : 170);visits[r.id]?.target=CGPoint(x:state.residents[i].x,y:state.residents[i].y)}}}
   state.life!.award("coexist.first",now);result="左侧留窝、右侧巡逻，伙伴错时来访；共居安排完成"
  case "adopt":
   guard state.residents.count<maxResidents else{tell("住客已满，先保留领养码，腾出空间后再接收");return}
   let (r,msg)=state.life!.adopt(text.trimmingCharacters(in:.whitespacesAndNewlines),now);result=msg;if let r=r {state.residents.append(r);summon(r.id,now)}
  default:
   guard let id=id,let r=state.residents.first(where:{$0.id==id && $0.live}) else{tell("先选择一位住客；可撒面包屑邀请旮杂");return}
   if action=="share" {if let code=state.life!.share(id,now){NSPasteboard.general.clearContents();NSPasteboard.general.setString(code,forType:.string);result="领养码已复制。副本领养，不带纸条和资源"}else{result="先命名或培养成伙伴，再生成领养码"}}
   else if action=="patrol" {
    guard r.friend,state.life!.bonds[id.uuidString.lowercased()]?.partner==true else{tell("请选择已成为伙伴的老鼠或猫");return}
    guard now>=state.life!.guardUntil else{tell("伙伴还在值班，右半屏正在保持安静");return}
    let targets=state.residents.filter{$0.live && !$0.friend && !state.protected($0) && visits[$0.id]?.hidden==false && $0.x >= (visits[$0.id]?.screen.midX ?? 0)}
    for t in targets {visits[t.id]=Visit()};state.life!.guardSide="right";state.life!.guardUntil=now+60;summon(id,now)
    if !targets.isEmpty {state.life!.award(r.kind == .mouse ? "patrol.first" : "guard.first",now)}
    result="右半屏值班 60 秒 · 驱赶 \(targets.count) 只；不伤害伙伴、不产生击杀奖励"
   } else if action=="gold" {
    guard r.kind == .gold,(state.life!.bonds[id.uuidString.lowercased()]?.trust ?? 0)>=2 else{tell("黄金旮杂信任达到 2 后，会留下一次卵壳");return}
    let amount=state.life!.gold(id,now);state.progression!.shells+=amount;result=amount>0 ? "它留给你 2 枚黄金卵壳，仍可以继续做朋友" : "这位住客的卵壳已收获过啦"
   } else {summon(id,now);result=action=="recall" ? "它听见你了，出来见一面" : state.life!.interact(r,action:action,text:text,now:now)}
  }
  tell(result);syncPanels();save();rebuildMenu()
 }
}
extension Paradise {
 func syncTrace(){
  guard !isTestRun else{return}
  if state.life?.traceReady==true && !paused && !state.quiet && !state.focusing,let f=NSScreen.main?.visibleFrame {
   if tracePanel==nil {let p=PetPanel(contentRect:NSRect(x:f.maxX-145,y:f.minY+40,width:115,height:34),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);p.isOpaque=false;p.backgroundColor = .clear;p.level = .floating;p.hasShadow=false;p.isReleasedWhenClosed=false;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.contentView=ActionButton("👣 金色碎屑",frame:NSRect(x:0,y:0,width:115,height:34)){[weak self] in self?.lifeAction("explore",id:nil,text:"",note:nil);self?.showLife()};tracePanel=p}
   tracePanel?.setFrameOrigin(NSPoint(x:f.maxX-145,y:f.minY+40));tracePanel?.orderFrontRegardless()
  } else {tracePanel?.orderOut(nil)}
 }
}
