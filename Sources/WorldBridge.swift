import Foundation
import CryptoKit
extension GameState {
    mutating func ensureWorld(_ old:Habitat?=nil) {
        guard world==nil else{return}
        var w=World(seed:UInt64.random(in:1...0xffffffff))
        if let old=old {for key in old.folders.keys.sorted().prefix(60) {let i=w.habitat(key.lowercased());w.habitats[i].activity=min(1,old.folders[key]!.visits/10)}}
        for r in residents where !r.friend {_=w.add(r.kind.rawValue,"edge",id:r.id.uuidString.lowercased(),record:false)}
        world=w
        // Historical trace timers are not evidence of an actual nest.
        life?.traceReady=false
    }
    mutating func reconcileWorld() {
        ensureWorld();var w=world!
        let ids=Set(residents.filter{!$0.friend}.map{$0.id.uuidString.lowercased()})
        for c in w.creatures where !ids.contains(c.id) {w.event(c.id,c.location,"removed by player",c.stage,"removed","player")}
        w.creatures.removeAll{!ids.contains($0.id)}
        for r in residents where !r.friend {
            let key=r.id.uuidString.lowercased()
            if !w.creatures.contains(where:{$0.id==key}) {_=w.add(r.kind.rawValue,"edge",id:key,record:false)}
            if let i=w.creatures.firstIndex(where:{$0.id==key}) {if w.creatures[i].stage != r.kind.rawValue {let previous=w.creatures[i].stage;if w.creatures[i].roach && !r.live {w.deaths+=1};w.event(key,w.creatures[i].location,"tool",previous,r.kind.rawValue,"player")};w.creatures[i].stage=r.kind.rawValue;w.creatures[i].protected=protected(r);w.creatures[i].trust=Double(life?.bonds[key]?.trust ?? 0)}
        }
        world=w
    }
    mutating func worldSignal(_ kind:String,id:UUID?=nil,location:String?=nil) {
        reconcileWorld();let key=id?.uuidString.lowercased() ?? ""
        let loc=location ?? world!.creatures.first{$0.id==key}?.location ?? "edge"
        world!.send(WorldSignal(kind:kind,location:loc,entity:key))
    }
    mutating func stepWorld(rate:Double,now:Double,safeIDs:Set<String>=[]) {
        reconcileWorld();world!.capacity=max(0,38-residents.filter{$0.friend}.count)
        for i in world!.creatures.indices where safeIDs.contains(world!.creatures[i].id) {world!.creatures[i].protected=true}
        world!.step(rate:rate)
        let snapshot=world!
        let liveIDs=Set(snapshot.creatures.map{$0.id})
        residents.removeAll{!$0.friend && !liveIDs.contains($0.id.uuidString.lowercased())}
        for c in snapshot.creatures {
            guard let id=UUID(uuidString:c.id),let kind=BugKind(rawValue:c.stage) else{continue}
            if let i=residents.firstIndex(where:{$0.id==id}) {
                let was=residents[i]
                residents[i].ecologyIntent=c.intent
                if was.live && kind == .corpse && c.playerChemical {life?.defeat(now);captures+=1;gain(2);if was.kind == .gold {migrateProgression();let amount=life!.gold(id,now);progression!.shells+=amount}}
                if was.kind != kind {residents[i].kind=kind;residents[i].born=now}
            } else {residents.append(Resident(id:id,kind:kind,x:12,y:24,born:now,ecologyIntent:c.intent))}
        }
        life?.traceReady=snapshot.habitats.contains{$0.nest && $0.exposed && !$0.discovered}
    }
    static func locationKey(_ identity:String)->String {SHA256.hash(data:Data(identity.utf8)).map{String(format:"%02x",$0)}.joined()}
}
