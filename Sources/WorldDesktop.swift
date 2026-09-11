import AppKit
extension Paradise {
    func ecology(_ now:Double) {
        state.ensureWorld(habitat)
        let safeIDs=Set(state.residents.filter{state.life?.safeLeft==true && $0.x<(NSScreen.main?.frame.midX ?? 0)}.map{$0.id.uuidString.lowercased()})
        state.stepWorld(rate:habitat.rate,now:now,safeIDs:safeIDs)
        let w=state.world!
        if CommandLine.arguments.contains("--world-log") {let encoder=JSONEncoder();for event in w.recentEvents where (event.sequence ?? 0)>lastLoggedSequence {if let data=try? encoder.encode(event),let line=String(data:data,encoding:.utf8){print(line);lastLoggedSequence=event.sequence ?? lastLoggedSequence}}}
        for c in w.creatures {
            guard let id=UUID(uuidString:c.id),let r=state.residents.first(where:{$0.id==id}) else{continue}
            if !r.live {visits.removeValue(forKey:id);continue}
            if c.visibleUntil>w.time && visits[id]?.hidden != false && visibleLiveCount<3 && now>=nextAppearance {
                let origin=c.emergedFrom
                let f=folderFrames[origin]
                let p=f.map{Habitat.border($0,side:0,fraction:0.5)}
                beginVisit(id,now:now,from:p)
                if let f=f,let p=p {entrances[id]=(f,now+2.5);visits[id]?.target=CGPoint(x:p.x-140,y:p.y)}
            }
            if c.intent=="freeze",visits[id]?.hidden==false,let i=state.residents.firstIndex(where:{$0.id==id}) {state.residents[i].holdUntil=now+2}
            if ["hide","rest","nest"].contains(c.intent),let visit=visits[id],!visit.hidden,(r.holdUntil ?? 0)<now {visits[id]?.deadline=min(visit.deadline,now+1)}
        }
        if !w.visitorKind.isEmpty,let k=BugKind(rawValue:w.visitorKind),state.residents.filter({$0.kind==k && visits[$0.id]?.hidden == false}).count < (k == .mouse ? 2 : 1) {spawnFriend(k,now:now)}
        syncPanels();save()
    }
}
