import Foundation
func runWorldTests(){
    var w=World(seed:7);let id=w.add("adult","edge",record:false);w.creatures[0].protected=true;w.creatures[0].cooldown=1000
    w.send(WorldSignal(kind:"chemical",entity:id));for _ in 0..<200 {w.step()}
    precondition(w.creatures[0].roach && w.deaths==0,"Chemical cannot harm protected individuals")
    var game=GameState();game.ensureLife();let r=Resident(kind:.adult,x:0,y:0,born:0);game.residents=[r]
    _=game.life!.interact(r,action:"name",text:"旧名字",now:1)
    game.life!.notes=[NoteItem(text:"private")];game.life!.cards=["name.roach":1]
    var legacy=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(game)) as! [String:Any];legacy.removeValue(forKey:"world")
    var migrated=try! JSONDecoder().decode(GameState.self,from:JSONSerialization.data(withJSONObject:legacy));migrated.ensureWorld();migrated.reconcileWorld()
    precondition(migrated.world!.recentEvents.isEmpty && migrated.world!.births==0 && migrated.world!.creatures[0].protected)
    precondition(migrated.life!.notes[0].text=="private" && migrated.life!.cards.count==1 && migrated.life!.bonds[r.id.uuidString.lowercased()]!.name=="旧名字")
    let defaults=try! JSONDecoder().decode(World.self,from:Data("{\"seed\":9,\"habitats\":[{\"id\":\"old\"}],\"creatures\":[{\"id\":\"old\"}]}".utf8))
    precondition(defaults.rng==9 && defaults.habitats[0].nestability==0.8 && defaults.creatures[0].energy==1)
    var before=World(seed:42);_=before.add("adult","edge",record:false);before.send(WorldSignal(kind:"food"));for _ in 0..<50 {before.step()}
    var resumed=try! JSONDecoder().decode(World.self,from:JSONEncoder().encode(before));for _ in 0..<100 {before.step();resumed.step()}
    let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
    precondition(try! encoder.encode(before)==encoder.encode(resumed),"Save resumes PRNG and ecological time")
    migrated.worldSignal("chemical",id:r.id);migrated.residents=[];migrated.stepWorld(rate:1,now:10)
    precondition(migrated.residents.isEmpty,"Projection must not resurrect removed identities")
    var chemical=GameState();chemical.progression!.owned=Tool.allCases;chemical.residents=[r];chemical.world=World(seed:4);chemical.reconcileWorld();chemical.world!.creatures[0].cooldown=1000;chemical.world!.creatures[0].resistance=0
    _=chemical.use(.poison,on:r.id,now:0,flightRoll:1)
    for n in 0..<40 {chemical.stepWorld(rate:1,now:Double(n)*2)}
    precondition(chemical.life!.kills==1 && chemical.captures==1)
    chemical.stepWorld(rate:1,now:100);precondition(chemical.life!.kills==1,"Delayed chemical settlement is exactly once")
    print("PASS: World defaults, legacy identity/notes/cards preservation, no fabricated migration history, protected dose, PRNG resume, no resurrection, chemical rewards exactly once")
}
