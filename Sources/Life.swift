import Foundation

struct Bond:Codable {
    var kind:String
    var name=""
    var trust=0
    var fear=0
    var partner=false
    var adopted=false
    var lastInteraction:Double = -100
    var protected:Bool {partner || adopted || !name.isEmpty}
}
struct NoteItem:Codable {var id=UUID().uuidString;var text:String;var done=false}
struct Adoption:Codable {var version=1;var token:String;var kind:String;var name:String}
struct Life:Codable {
    var bonds:[String:Bond]=[:]
    var cards:[String:Double]=[:]
    var kills=0
    var goldPaid:[String]=[]
    var notes:[NoteItem]=[]
    var received:[String]=[]
    var focusRemaining:Double=0
    var traceReady=false
    var traceClock:Double=0
    var safeLeft=false
    var guardSide=""
    var guardUntil:Double=0
    static let achievements:[(String,String)]=[
        ("combat.first","第一回合"),("combat.three","三只了！"),("gold.first","金光一闪"),
        ("meet.mouse","有鼠来访"),("meet.cat","谁把爪子放这了"),("touch.mouse","摸到小老鼠"),("touch.cat","软乎乎的爪背"),
        ("bond.roach","我的第一位室友"),("bond.mouse","巡逻员报到"),("bond.cat","猫咪认得你了"),("name.roach","你有名字啦"),
        ("feed.first","请你吃一口"),("stash.first","替我收好"),("stash.return","还真给我找回来了"),("trace.first","顺着脚印"),
        ("nest.first","原来住在这里"),("patrol.first","今天有人值班"),("guard.first","大爪子镇场"),("coexist.first","大家都有地方住"),
        ("focus.first","约好了，先安静"),("adoption.first","新室友远道而来"),("share.first","带着故事出发")]
    mutating func award(_ key:String,_ now:Double){if cards[key]==nil {cards[key]=now}}
    mutating func observe(_ r:Resident,_ now:Double){
        let key=r.id.uuidString.lowercased()
        if bonds[key]==nil {bonds[key]=Bond(kind:r.kind.rawValue)}
        if r.kind == .mouse {award("meet.mouse",now)}
        if r.kind == .catPaw {award("meet.cat",now)}
    }
    func protects(_ id:UUID)->Bool {bonds[id.uuidString.lowercased()]?.protected == true}
    mutating func gold(_ id:UUID,_ now:Double)->Int {
        let key=id.uuidString.lowercased();guard !goldPaid.contains(key) else{return 0}
        goldPaid.append(key);award("gold.first",now);return 2
    }
    mutating func defeat(_ now:Double){kills+=1;if kills>=1 {award("combat.first",now)};if kills>=3 {award("combat.three",now)}}
    mutating func interact(_ r:Resident,action:String,text:String,now:Double)->String {
        observe(r,now);let key=r.id.uuidString.lowercased();var b=bonds[key]!
        switch action {
        case "name":
            let name=String(text.trimmingCharacters(in:.whitespacesAndNewlines).prefix(24));guard !name.isEmpty else{return "先输入名字（最多 24 字）"}
            b.name=name;if !r.friend {award("name.roach",now)}
        case "bond":
            guard b.trust>=6 else{return "它还在试着认识你，再相处一阵吧"}
            guard !b.partner else{return "已经是伙伴啦"}
            guard bonds.values.filter({$0.partner}).count<6 else{return "伙伴位已满（6 位），现有伙伴会继续受到保护"}
            b.partner=true;award(r.kind == .mouse ? "bond.mouse" : r.kind == .catPaw ? "bond.cat" : "bond.roach",now)
        default:
            guard now-b.lastInteraction>=20 else{return "它还在享受刚才的互动，稍等一会儿"}
            b.lastInteraction=now;b.trust+=1;b.fear=max(0,b.fear-1)
            if action=="feed" {award("feed.first",now)}
            if action=="pet" && r.kind == .mouse {award("touch.mouse",now)}
            if action=="pet" && r.kind == .catPaw {award("touch.cat",now)}
        }
        bonds[key]=b
        return action=="bond" ? "伙伴入住！它会记得你，也会受到保护" : action=="name" ? "名字已记住，住客保护已开启" : "它认得你的手了 ♡"
    }
    mutating func stash(_ text:String,_ now:Double)->String {
        guard bonds.values.contains(where:{$0.trust>=2 || $0.adopted}) else{return "先和一位住客熟悉起来，它就愿意替你收着"}
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty && value.count<=4000 && notes.count<100 else{return "输入 1–4000 字，收纳上限 100 条"}
        notes.append(NoteItem(text:value));award("stash.first",now);return "纸条已收进窝里；随时可从清单取回"
    }
    mutating func share(_ id:UUID,_ now:Double)->String? {
        guard let b=bonds[id.uuidString.lowercased()],b.protected else{return nil}
        let card=Adoption(token:UUID().uuidString.lowercased(),kind:b.kind,name:b.name)
        guard let data=try? JSONEncoder().encode(card) else{return nil}
        award("share.first",now);return "GALA1:"+data.base64EncodedString()
    }
    mutating func adopt(_ code:String,_ now:Double)->(Resident?,String) {
        guard code.count<4096,code.hasPrefix("GALA1:"),let data=Data(base64Encoded:String(code.dropFirst(6))),let card=try? JSONDecoder().decode(Adoption.self,from:data),card.version==1,UUID(uuidString:card.token) != nil,let kind=BugKind(rawValue:card.kind),[BugKind.adult,.baby,.gold,.mouse,.catPaw].contains(kind),card.name.count<=24 else{return(nil,"领养码无效或版本不支持")}
        guard !received.contains(card.token.lowercased()) else{return(nil,"这个领养码已经接收过了")}
        let r=Resident(kind:kind,x:0,y:0,born:now);received.append(card.token.lowercased());observe(r,now)
        bonds[r.id.uuidString.lowercased()]=Bond(kind:kind.rawValue,name:card.name,adopted:true)
        // Adoption never imports repeatable currency from another save.
        if kind == .gold {goldPaid.append(r.id.uuidString.lowercased())}
        award("adoption.first",now);return(r,"新室友入住；本地信任从零开始")
    }
    mutating func tick(_ dt:Double,_ now:Double)->Bool {
        if focusRemaining>0 {focusRemaining=max(0,focusRemaining-min(max(dt,0),1));if focusRemaining==0 {award("focus.first",now);return true};return false}
        return false
    }
}
extension GameState {
    mutating func ensureLife(){if life==nil {life=Life()}}
    var focusing:Bool {(life?.focusRemaining ?? 0)>0}
    func protected(_ r:Resident)->Bool {life?.protects(r.id)==true}
}
func runLifeTests(){
    let r=Resident(kind:.adult,x:0,y:0,born:0);var l=Life()
    for n in 0..<6 {_=l.interact(r,action:"pet",text:"",now:Double(n)*21)}
    _=l.interact(r,action:"bond",text:"",now:130);precondition(l.protects(r.id))
    let trust=l.bonds[r.id.uuidString.lowercased()]!.trust;_=l.interact(r,action:"feed",text:"",now:106);precondition(l.bonds[r.id.uuidString.lowercased()]!.trust==trust)
    precondition(l.gold(r.id,140)==2 && l.gold(r.id,141)==0)
    let code=l.share(r.id,150)!;let (newR,_)=l.adopt(code,151);precondition(newR != nil && l.adopt(code,152).0==nil)
    _=l.stash("测试私密纸条",160);precondition(l.notes.count==1 && !code.contains("纸条"))
    l.focusRemaining=1;precondition(l.tick(1,170) && l.cards["focus.first"] != nil)
    var g=GameState();g.life=l;g.residents=[r];_=g.use(.pinch,on:r.id,now:180,flightRoll:1);precondition(g.residents[0].live)
    var legacy=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(g)) as! [String:Any];legacy.removeValue(forKey:"life")
    var migrated=try! JSONDecoder().decode(GameState.self,from:JSONSerialization.data(withJSONObject:legacy));migrated.ensureLife();precondition(migrated.residents.count==1 && migrated.life!.cards.isEmpty)
    let restored=try! JSONDecoder().decode(Life.self,from:JSONEncoder().encode(l));precondition(restored.notes.count==1 && restored.protects(r.id))
    for kind in [BugKind.mouse,.catPaw] {
        var game=GameState();game.progression!.owned=Tool.allCases
        let animal=Resident(kind:kind,x:120,y:140,born:0);game.residents=[animal]
        for (index,tool) in Tool.allCases.enumerated(){let now=1000+Double(index)*21;let response=game.use(tool,on:animal.id,now:now,flightRoll:1);precondition(!response.isEmpty && game.residents[0].live && (game.residents[0].reactionUntil ?? 0)>now && game.captures==0)}
        let count=game.life!.bonds[animal.id.uuidString.lowercased()]!.trust
        _=game.use(.pinch,on:animal.id,now:2000,flightRoll:1);_=game.use(.pinch,on:animal.id,now:2001,flightRoll:1)
        precondition(game.life!.bonds[animal.id.uuidString.lowercased()]!.trust==count+1)
    }
    print("PASS: all five tools react on mouse/cat without damage; repeated clicks preserve relationship cooldown")
    print("PASS: bonds, cooldown, protection, one-time gold, adoption deduplication, private stash, focus and persistence")
}
