import Foundation
import CryptoKit

struct FolderHistory:Codable {
    var visits:Double=0
    var lastSeen:Double=0
}
struct Habitat:Codable {
    var rate:Double=1
    var folders:[String:FolderHistory]=[:]
    var cleanUntil:Double=0
    mutating func opened(_ identity:String,now:Double) -> (count:Int,eggs:Bool) {
        let key=SHA256.hash(data:Data(identity.utf8)).map{String(format:"%02x",$0)}.joined()
        var h=folders[key] ?? FolderHistory()
        let elapsed=h.lastSeen==0 ? 0 : max(0,now-h.lastSeen)
        h.visits *= exp(-elapsed/21600)
        let risk=min(1,0.8+elapsed*rate/7200)/(1+h.visits*0.7)
        h.visits+=1;h.lastSeen=now;folders[key]=h
        if folders.count>256,let oldest=folders.min(by:{$0.value.lastSeen<$1.value.lastSeen})?.key {folders.removeValue(forKey:oldest)}
        guard now>=cleanUntil else{return (0,false)}
        return (min(3,Int(risk*3)),risk>0.55)
    }
    mutating func clean(now:Double) {cleanUntil=now+300;for key in Array(folders.keys){var h=folders[key]!;h.visits=max(6,h.visits);h.lastSeen=now;folders[key]=h}}
    // AppKit desktop coordinates are bottom-up. Align the sprite's visual center to the window edge.
    static func border(_ f:CGRect,side:Int,fraction:Double) -> CGPoint {
        let t=min(0.9,max(0.1,fraction))
        switch side {
        case 0:return CGPoint(x:f.minX-73,y:f.minY+f.height*t-25)
        case 1:return CGPoint(x:f.maxX-73,y:f.minY+f.height*t-25)
        case 2:return CGPoint(x:f.minX+f.width*t-73,y:f.minY-25)
        default:return CGPoint(x:f.minX+f.width*t-73,y:f.maxY-25)
        }
    }
}
func runHabitatTests(){
    var h=Habitat();let now=1000.0
    let first=h.opened("folder-a",now:now)
    for i in 1...8 {_=h.opened("folder-a",now:now+Double(i)*2)}
    precondition(first.count==2 && first.eggs)
    precondition(h.opened("folder-a",now:now+20).count==0)
    precondition(h.opened("folder-b",now:now+20).count==2)
    precondition(h.opened("folder-a",now:now+86400).count>=2)
    h.clean(now:now+86401);precondition(h.opened("folder-c",now:now+86402).count==0)
    h.rate=3;let d=try! JSONEncoder().encode(h);let copy=try! JSONDecoder().decode(Habitat.self,from:d);precondition(copy.rate==3 && copy.cleanUntil==h.cleanUntil)
    let f=CGRect(x:100,y:100,width:800,height:500)
    for side in 0..<4 {let p=Habitat.border(f,side:side,fraction:0.5);let center=CGPoint(x:p.x+73,y:p.y+25);precondition(center.x==f.minX || center.x==f.maxX || center.y==f.minY || center.y==f.maxY)}
    print("PASS: folder border alignment, frequent vs neglected folders, scan protection, habitat persistence")
}
