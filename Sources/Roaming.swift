import Foundation

// Visits are session-only: old save files keep all residents and progression unchanged.
// Positions refer to the lower-left corner of a transparent 146 × 140 pet panel.
struct Visit {
    var hidden = true
    var exiting = false
    var deadline: Double = 0
    var target = CGPoint.zero
    var screen = CGRect.zero

    static func edgePoint(_ edge: Int, in screen: CGRect, fraction: Double) -> CGPoint {
        let x=screen.minX+screen.width*fraction-73
        let y=screen.minY+screen.height*fraction-35
        switch edge {
        case 0: return CGPoint(x:screen.minX-146,y:y)
        case 1: return CGPoint(x:screen.maxX,y:y)
        case 2: return CGPoint(x:x,y:screen.minY-140)
        default: return CGPoint(x:x,y:screen.maxY)
        }
    }
    static func nearestExit(from point:CGPoint,in screen:CGRect) -> CGPoint {
        (0..<4).map { edge -> CGPoint in
            switch edge {
            case 0:return CGPoint(x:screen.minX-146,y:point.y)
            case 1:return CGPoint(x:screen.maxX,y:point.y)
            case 2:return CGPoint(x:point.x,y:screen.minY-140)
            default:return CGPoint(x:point.x,y:screen.maxY)
            }
        }.min {hypot($0.x-point.x,$0.y-point.y)<hypot($1.x-point.x,$1.y-point.y)}!
    }
    mutating func advance(_ r:inout Resident, now:Double,dt:Double,speed:Double) {
        guard !hidden else{return}
        if !exiting && now>=deadline {
            exiting=true
            target=Self.nearestExit(from:CGPoint(x:r.x,y:r.y),in:screen)
        }
        let dx=target.x-r.x,dy=target.y-r.y,distance=hypot(dx,dy)
        let step=speed*dt
        r.vx=dx; r.vy=dy
        if distance<=max(1,step) {
            r.x=target.x;r.y=target.y
            if exiting {hidden=true;r.tauntUntil=0}
        } else {r.x+=dx/distance*step;r.y+=dy/distance*step}
    }
}
func desktopSize(_ kind:BugKind) -> CGFloat {
    switch kind {case .mouse:return 104;case .catPaw:return 140;case .baby:return 45;case .egg:return 52;default:return 68}
}
func runRoamingTests() {
    let f=CGRect(x:-1440,y:40,width:1440,height:860)
    for edge in 0..<4 {
        let p=Visit.edgePoint(edge,in:f,fraction:0.5)
        precondition(!f.intersects(CGRect(x:p.x,y:p.y,width:146,height:140)))
    }
    var r=Resident(kind:.adult,x:-1000,y:300,born:0)
    var v=Visit(hidden:false,exiting:false,deadline:3,target:CGPoint(x:-900,y:300),screen:f)
    v.advance(&r,now:1,dt:1,speed:50)
    precondition(r.x == -950 && !v.hidden)
    v.advance(&r,now:4,dt:100,speed:50)
    precondition(v.exiting && v.hidden)
    let x=r.x,y=r.y
    v.advance(&r,now:500,dt:100,speed:50)
    precondition(r.x==x && r.y==y)
    precondition(desktopSize(.adult)==68 && desktopSize(.baby)==45)
    print("PASS: four offscreen entrances, negative display coordinates, walking, exit, hidden stability, smaller sizes")
}
