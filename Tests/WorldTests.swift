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
    var chemical=GameState();chemical.progression!.owned=Tool.allCases;chemical.residents=[r];chemical.world=World(seed:4);chemical.reconcileWorld();chemical.world!.habitats=[WorldHabitat()];chemical.world!.creatures[0].cooldown=1000;chemical.world!.creatures[0].resistance=0
    _=chemical.use(.poison,on:r.id,now:0,flightRoll:1)
    for n in 0..<40 {chemical.stepWorld(rate:1,now:Double(n)*2)}
    precondition(chemical.life!.kills==1 && chemical.captures==1)
    chemical.stepWorld(rate:1,now:100);precondition(chemical.life!.kills==1,"Delayed chemical settlement is exactly once")
    runReadableWorldTests()
    print("PASS: World defaults, legacy identity/notes/cards preservation, no fabricated migration history, protected dose, PRNG resume, no resurrection, chemical rewards exactly once")
}

func runReadableWorldTests(){
 var w=World(seed:42);w.time=100
 var c=WorldCreature(id:"test",location:"A",locationMemory:"A")
 var a=WorldHabitat(id:"A",food:0.2);var b=WorldHabitat(id:"B",food:0.9)
 precondition(w.migrationAllowed(c,a,b),"A sustained better habitat remains reachable")
 c.lastMigrationTime=90
 precondition(!w.migrationAllowed(c,a,b),"Recent commitment prevents routine reversal")
 a.chemical=0.9;c.cooldown=1000
 precondition(w.migrationAllowed(c,a,b),"Chemical interrupts both commitment and breeding cooldown")
 a.chemical=0;a.disturbance=0.9;precondition(w.migrationAllowed(c,a,b))
 a.disturbance=0;c.fear=1;precondition(w.migrationAllowed(c,a,b))
 c.fear=0;c.cooldown=0;c.lastMigrationTime = -1;b.food=0.65
 precondition(!w.migrationAllowed(c,a,b),"Small advantage is insufficient")
 w.migrationMode="control";precondition(w.migrationAllowed(c,a,b),"Exact old threshold remains available for control")
 c.previousLocation="B";c.lastMigrationTime=0;w.time=120;w.recordMigration(&c,to:"B",chemical:0.7);precondition(w.reversals==1 && w.chemicalMigrations==1)
 c.location="B";w.time=242;w.recordMigration(&c,to:"A",chemical:0);precondition(w.reversals==1,"122 seconds is outside frozen window")
 let old=try! JSONDecoder().decode(World.self,from:Data("{\"creatures\":[{\"id\":\"old\",\"stage\":\"egg\",\"age\":63}]}".utf8))
 precondition(old.creatures[0].lastMigrationTime == -1 && old.creatures[0].previousLocation.isEmpty && old.creatures[0].age==63 && old.reversals==0)
 let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 let one=BlindSession(root:root),two=BlindSession(root:root);precondition(one.directory != two.directory)
 one.action("name",entity:UUID().uuidString,location:"private-folder");one.action("private text");one.observe(w);try! one.flush()
 let log=try! String(contentsOf:one.directory.appendingPathComponent("observations.jsonl"),encoding:.utf8)
 precondition(!log.contains("private-folder") && !log.contains("private text") && log.contains("worldSeed"))
 try? FileManager.default.removeItem(at:root)
 print("PASS: hysteresis, commitment, emergency interrupt, reversal boundary, missing migration fields, isolated blind log allowlist")
}
