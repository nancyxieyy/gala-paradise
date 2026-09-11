import Foundation
// Explicit allowlist. Never pass UI text, file identities, names or clipboard data here.
final class BlindSession {
    let directory:URL
    var pending=Data();var lastSequence:UInt64=0;var seedRecorded=false
    private var locations:[String:String]=[:]
    private var previous:[String:(String,String,Double)]=[:]
    static let actions:Set<String>=["pinch","slipper","poison","vacuum","cleaner","visit","food","chemical","clean","threat","friendly","pet","feed","name","bond","gold","patrol","leave","recall","safe","coexist","adopt","share","stash","return","done","delete","focus","cancel","pause","resume","release","select","rate"]
    init(root:URL) {directory=root.appendingPathComponent("BlindPlaytests").appendingPathComponent(UUID().uuidString.lowercased())}
    func location(_ raw:String)->String {if raw.isEmpty {return ""};if let alias=locations[raw] {return alias};let alias="h\(locations.count+1)";locations[raw]=alias;return alias}
    func append(_ record:[String:Any]) {guard let data=try? JSONSerialization.data(withJSONObject:record,options:.sortedKeys) else{return};pending.append(data);pending.append(10)}
    func action(_ kind:String,entity:String="",location raw:String="",time:Double=0) {
        guard Self.actions.contains(kind) else{return}
        append(["timestamp":Date().timeIntervalSince1970,"worldTime":time,"playerAction":kind,"location":location(raw),"entity":UUID(uuidString:entity)?.uuidString.lowercased() ?? ""])
    }
    func observe(_ w:World) {
        if !seedRecorded {append(["timestamp":Date().timeIntervalSince1970,"worldSeed":w.seed,"version":"1.7.1"]);seedRecorded=true;lastSequence=0}
        for e in w.recentEvents where (e.sequence ?? 0)>lastSequence {
            let id=UUID(uuidString:e.entity)?.uuidString.lowercased() ?? (["nest","habitat","mouse","catPaw"].contains(e.entity) ? e.entity : "")
            var row:[String:Any]=["timestamp":Date().timeIntervalSince1970,"worldTime":e.timestamp,"sequence":e.sequence ?? 0,"worldEvent":e.trigger,"rule":e.rule,"entity":id,"location":location(e.location)]
            if e.trigger=="migration" {row["from"]=location(e.previous);row["to"]=location(e.new);row["reversal"]=previous[id].map{$0.0==e.new && $0.1==e.previous && e.timestamp-$0.2<=120} ?? false;previous[id]=(e.previous,e.new,e.timestamp)}
            if ["adult","baby","gold","egg","hatched","corpse","removed","nest","clear"].contains(e.new) {row["stage"]=e.new}
            append(row);lastSequence=e.sequence ?? lastSequence
        }
    }
    func flush() throws {
        guard !pending.isEmpty else{return}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let path=directory.appendingPathComponent("observations.jsonl")
        if !FileManager.default.fileExists(atPath:path.path) {FileManager.default.createFile(atPath:path.path,contents:nil)}
        let handle=try FileHandle(forWritingTo:path);defer{try? handle.close()};try handle.seekToEnd();try handle.write(contentsOf:pending);pending.removeAll(keepingCapacity:true)
    }
}
