import Foundation
import CryptoKit

struct FolderHistory: Codable {
    var visits: Double = 0
    var lastSeen: Double = 0
}
struct Habitat: Codable {
    var rate: Double = 1
    var folders: [String: FolderHistory] = [:]
    var cleanUntil: Double = 0
    mutating func clean(now: Double) {
        cleanUntil = now + 300
        for key in Array(folders.keys) {
            var h = folders[key]!
            h.visits = max(6, h.visits)
            h.lastSeen = now
            folders[key] = h
        }
    }
    // AppKit desktop coordinates are bottom-up. Align the sprite's visual center to the window edge.
    static func border(_ f: CGRect, side: Int, fraction: Double) -> CGPoint {
        let t = min(0.9, max(0.1, fraction))
        switch side {
        case 0: return CGPoint(x: f.minX - 73, y: f.minY + f.height * t - 25)
        case 1: return CGPoint(x: f.maxX - 73, y: f.minY + f.height * t - 25)
        case 2: return CGPoint(x: f.minX + f.width * t - 73, y: f.minY - 25)
        default: return CGPoint(x: f.minX + f.width * t - 73, y: f.maxY - 25)
        }
    }
}
func runHabitatTests() {
    var h = Habitat()
    h.rate = 3
    let d = try! JSONEncoder().encode(h)
    let copy = try! JSONDecoder().decode(Habitat.self, from: d)
    precondition(copy.rate == 3)
    let f = CGRect(x: 100, y: 100, width: 800, height: 500)
    for side in 0..<4 {
        let p = Habitat.border(f, side: side, fraction: 0.5)
        let center = CGPoint(x: p.x + 73, y: p.y + 25)
        precondition(center.x == f.minX || center.x == f.maxX || center.y == f.minY || center.y == f.maxY)
    }
    print("PASS: folder border alignment, habitat persistence")
}
