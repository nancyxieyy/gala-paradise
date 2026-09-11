import AppKit
final class ReactionView:NSView {
 let text:String
 init(_ text:String){self.text=text;super.init(frame:NSRect(x:0,y:0,width:250,height:48))}
 required init?(coder:NSCoder){fatalError()}
 override var isFlipped:Bool{true}
 override func draw(_ dirtyRect:NSRect){paintRect(bounds.insetBy(dx:2,dy:2),cream,radius:16,stroke:color(0xCFD7BD));label(text,13,13,size:12,weight:.medium,width:224)}
}
extension Paradise {
 func showReaction(_ text:String,for r:Resident){
  guard !isTestRun else{return}
  reactions[r.id]?.close()
  let f=NSScreen.screens.first{$0.frame.contains(NSPoint(x:r.x+50,y:r.y+50))}?.visibleFrame ?? NSScreen.main!.visibleFrame
  let x=max(f.minX+4,min(f.maxX-254,r.x+(petCanvas(r.kind).width-250)/2));let y=max(f.minY+4,min(f.maxY-52,r.y+desktopSize(r.kind)*0.8))
  let p=PetPanel(contentRect:NSRect(x:x,y:y,width:250,height:48),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=false;p.ignoresMouseEvents=true;p.level = .floating;p.isReleasedWhenClosed=false;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.contentView=ReactionView(text);reactions[r.id]=p;p.orderFrontRegardless()
  DispatchQueue.main.asyncAfter(deadline:.now()+1.8){[weak self,weak p] in guard let p=p else{return};p.close();if self?.reactions[r.id] === p {self?.reactions.removeValue(forKey:r.id)}}
 }
 func animalMenu(_ id:UUID,event:NSEvent,in view:NSView){
  guard let i=state.residents.firstIndex(where:{$0.id==id}),!paused,!state.focusing else{return}
  let r=state.residents[i];guard r.live else{interact(id);return}
  state.residents[i].holdUntil=Date().timeIntervalSince1970+30
  let menu=NSMenu();let b=state.life?.bonds[id.uuidString.lowercased()]
  menu.addItem(withTitle:(b?.name.isEmpty == false ? b!.name : r.kind == .mouse ? "小老鼠" : r.kind == .catPaw ? "猫咪" : "小旮杂")+"",action:nil,keyEquivalent:"")
  func add(_ title:String,_ action:String){let item=NSMenuItem(title:title,action:#selector(animalChoice(_:)),keyEquivalent:"");item.target=self;item.representedObject=[id.uuidString,action];menu.addItem(item)}
  add("♡ 摸一摸","pet");add("喂一口","feed");add("起个名字…","name");add(b?.partner == true ? "已经是我的伙伴 ♡" : "成为我的伙伴","bond")
  if r.kind == .gold {add("收下黄金卵壳","gold")}
  if r.friend && b?.partner==true {add("去右边巡逻","patrol")}
  menu.addItem(.separator());add("放它去玩","leave")
  NSMenu.popUpContextMenu(menu,with:event,for:view)
  if let index=state.residents.firstIndex(where:{$0.id==id}) {state.residents[index].holdUntil=Date().timeIntervalSince1970+1.5}
 }
 @objc func animalChoice(_ item:NSMenuItem){guard let a=item.representedObject as? [String],let id=UUID(uuidString:a[0]),let r=state.residents.first(where:{$0.id==id}) else{return};let action=a[1]
  if action=="leave" {if let i=state.residents.firstIndex(where:{$0.id==id}) {state.residents[i].holdUntil=0;visits[id]?.deadline=Date().timeIntervalSince1970};showReaction("好啦，去玩吧～",for:r);return}
  var text=""
  if action=="name" {let alert=NSAlert();alert.messageText="给它起个名字";alert.informativeText="它会记住这个名字。";let field=NSTextField(frame:NSRect(x:0,y:0,width:250,height:28));field.stringValue=state.life?.bonds[id.uuidString.lowercased()]?.name ?? "";alert.accessoryView=field;alert.addButton(withTitle:"就叫这个");alert.addButton(withTitle:"再想想");alert.window.initialFirstResponder=field;guard alert.runModal() == .alertFirstButtonReturn else{return};text=field.stringValue}
  lifeAction(action,id:id,text:text,note:nil,inPlace:true)
  if let i=state.residents.firstIndex(where:{$0.id==id}) {state.residents[i].reactionUntil=Date().timeIntervalSince1970+0.55;state.residents[i].holdUntil=Date().timeIntervalSince1970+1.5}
  let feedback=(action=="pet" || action=="feed") && message.contains("稍等") ? (action=="pet" ? "还想被摸摸 ♡" : "还在嚼呢，嚼嚼嚼～") : message
  showReaction(feedback,for:r)
 }
 @objc func connectFinderMenu(){connectFinder()}
 @objc func tryFolder(){previewFolder("试玩文件夹",point:NSPoint(x:150,y:150))}
 @objc func showOptions(){status.menu?.popUp(positioning:nil,at:NSPoint(x:boundsAnchor.x,y:boundsAnchor.y),in:dashboard)}
 var boundsAnchor:NSPoint{NSPoint(x:dashboard.bounds.width-45,y:65)}
}
