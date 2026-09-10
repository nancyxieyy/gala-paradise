import AppKit

let ink = NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.17, alpha: 1)
let cream = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1)
let moss = NSColor(calibratedRed: 0.27, green: 0.36, blue: 0.23, alpha: 1)
let orange = NSColor(calibratedRed: 0.86, green: 0.39, blue: 0.19, alpha: 1)
func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor { NSColor(calibratedRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8)&255)/255, blue: CGFloat(hex&255)/255, alpha: alpha) }
func paintRect(_ r: NSRect, _ fill: NSColor, radius: CGFloat = 0, stroke: NSColor? = nil, width: CGFloat = 1) {
    let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius); fill.setFill(); p.fill()
    if let stroke = stroke { stroke.setStroke(); p.lineWidth = width; p.stroke() }
}
func oval(_ r: NSRect, _ fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 2) {
    let p = NSBezierPath(ovalIn: r); fill.setFill(); p.fill()
    if let stroke = stroke { stroke.setStroke(); p.lineWidth = width; p.stroke() }
}
func line(_ pts: [NSPoint], _ c: NSColor = ink, _ width: CGFloat = 2) {
    guard let first = pts.first else { return }; let p = NSBezierPath(); p.move(to: first)
    for pt in pts.dropFirst() { p.line(to: pt) }; p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round; c.setStroke(); p.stroke()
}
func label(_ text: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 14, weight: NSFont.Weight = .regular, c: NSColor = ink, width: CGFloat = 800) {
    let para = NSMutableParagraphStyle(); para.lineBreakMode = .byTruncatingTail
    (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 1.8), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: c, .paragraphStyle: para])
}
// Original vector character: bean body, oversized googly eyes, loose antennae.
// Coordinates are in a flipped 140 × 140 space.
func drawBug(in box: NSRect, kind: BugKind = .adult, phase: Double = 0, flying: Bool = false, facing: Double = 1) {
    if kind == .mouse || kind == .catPaw {drawFriend(in:box,cat:kind == .catPaw,phase:phase,facing:facing);return}
    NSGraphicsContext.saveGraphicsState()
    let t = AffineTransform(translationByX: box.minX, byY: box.minY); (t as NSAffineTransform).concat()
    let s = AffineTransform(scaleByX: box.width/140, byY: box.height/140); (s as NSAffineTransform).concat()
    if kind == .stain {
        for n in 0..<8 {
            let a = Double(n) * 0.79
            oval(NSRect(x: 60 + cos(a)*27, y: 65 + sin(a)*17, width: 19+Double(n%3)*7, height: 18), color(0xDAB867, 0.82))
        }
        oval(NSRect(x: 36, y: 60, width: 65, height: 37), color(0xEBC976, 0.9))
        oval(NSRect(x: 42, y: 65, width: 15, height: 7), color(0xFFF1B9))
        oval(NSRect(x: 15, y: 58, width: 8, height: 6), color(0xDAB867)); oval(NSRect(x: 113, y: 99, width: 5, height: 5), color(0xDAB867))
    } else if kind == .egg {
        for n in 0..<3 {
            oval(NSRect(x: 29+CGFloat(n)*23, y: 70-CGFloat(n%2)*8, width: 29, height: 37), color(0xD9B78C), stroke: color(0x8C6948), width: 2.5)
            for k in 0..<3 { line([NSPoint(x: 36+CGFloat(n)*23, y: 79+CGFloat(k)*7-CGFloat(n%2)*8), NSPoint(x: 50+CGFloat(n)*23,y: 79+CGFloat(k)*7-CGFloat(n%2)*8)],color(0xAE8963),1.5) }
        }
    } else {
        let dead = kind == .corpse
        if dead { let a = AffineTransform(translationByX: 140, byY: 140); (a as NSAffineTransform).concat(); let r = AffineTransform(rotationByDegrees: 180); (r as NSAffineTransform).concat() }
        oval(NSRect(x: 27, y: 107, width: 95, height: 15), color(0x6E4C31, 0.16))
        let wiggle = sin(phase*12)*4
        for n in 0..<3 {
            let x = 37+CGFloat(n)*29
            line([NSPoint(x:x,y:91),NSPoint(x:x-9,y:111+wiggle),NSPoint(x:x-17,y:114+wiggle)], color(0x553821),4)
            line([NSPoint(x:x+10,y:87),NSPoint(x:x+24,y:103-wiggle),NSPoint(x:x+29,y:107-wiggle)], color(0x553821),4)
        }
        if flying {
            oval(NSRect(x: 0, y: 41, width: 73, height: 42+wiggle), color(0xE9F3DD,0.88), stroke: ink)
            oval(NSRect(x: 73, y: 35, width: 64, height: 49-wiggle), color(0xE9F3DD,0.88), stroke: ink)
        }
        let body = NSBezierPath(); body.move(to: NSPoint(x: 24,y: 70)); body.curve(to: NSPoint(x:117,y:53),controlPoint1:NSPoint(x:37,y:23),controlPoint2:NSPoint(x:86,y:27)); body.curve(to:NSPoint(x:116,y:104),controlPoint1:NSPoint(x:135,y:66),controlPoint2:NSPoint(x:125,y:87)); body.curve(to:NSPoint(x:32,y:110),controlPoint1:NSPoint(x:94,y:127),controlPoint2:NSPoint(x:49,y:122)); body.close()
        (kind == .gold ? color(0xE9BC3E) : color(0xA2653D)).setFill(); body.fill(); ink.setStroke(); body.lineWidth=3.5; body.stroke()
        let wing = NSBezierPath(); wing.move(to:NSPoint(x:78,y:39)); wing.curve(to:NSPoint(x:106,y:99),controlPoint1:NSPoint(x:101,y:48),controlPoint2:NSPoint(x:112,y:79)); color(0x76492F).setStroke(); wing.lineWidth=2.5; wing.stroke()
        oval(NSRect(x: 20,y:64,width:85,height:53),kind == .gold ? color(0xD5A528) : color(0x985B38),stroke:ink,width:3.5)
        for n in 0..<2 {
            let x = CGFloat(n)*42+22
            oval(NSRect(x:x,y:69,width:43,height:42),.white,stroke:ink,width:3.2)
            if dead {
                line([NSPoint(x:x+14,y:82),NSPoint(x:x+27,y:96)],ink,3)
                line([NSPoint(x:x+27,y:82),NSPoint(x:x+14,y:96)],ink,3)
            } else { oval(NSRect(x:x+19+facing*5,y:85,width:8,height:12),ink) }
        }
        let antenna = NSBezierPath(); antenna.move(to:NSPoint(x:42,y:71)); antenna.curve(to:NSPoint(x:35+wiggle,y:9),controlPoint1:NSPoint(x:31,y:44),controlPoint2:NSPoint(x:29,y:26)); antenna.move(to:NSPoint(x:68,y:68)); antenna.curve(to:NSPoint(x:87+wiggle,y:14),controlPoint1:NSPoint(x:71,y:48),controlPoint2:NSPoint(x:76,y:27)); ink.setStroke(); antenna.lineWidth=3; antenna.lineCapStyle = .round; antenna.stroke()
        oval(NSRect(x:99,y:51,width:8,height:5),color(0xC99167)); oval(NSRect(x:111,y:62,width:4,height:4),color(0xC99167))
        line([NSPoint(x:56,y:114),NSPoint(x:64,y:115),NSPoint(x:70,y:112)],ink,2)
    }
    NSGraphicsContext.restoreGraphicsState()
}

func menuPetIcon() -> NSImage {
    let image=NSImage(size:NSSize(width:23,height:22),flipped:true) { _ in
        oval(NSRect(x:5,y:7,width:14,height:13),.black)
        line([NSPoint(x:9,y:9),NSPoint(x:7,y:2),NSPoint(x:5,y:1)],.black,1.5)
        line([NSPoint(x:14,y:9),NSPoint(x:17,y:2),NSPoint(x:20,y:1)],.black,1.5)
        for y in [11.0,15.0,18.0] {
            line([NSPoint(x:6,y:y),NSPoint(x:2,y:y+2)],.black,1.2)
            line([NSPoint(x:18,y:y),NSPoint(x:22,y:y+2)],.black,1.2)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        oval(NSRect(x:8,y:10,width:3,height:4),.black)
        oval(NSRect(x:13,y:10,width:3,height:4),.black)
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    image.isTemplate=true
    return image
}

func drawSpray(in box:NSRect,elapsed:Double=0){
    if elapsed<0.65 {
    // A hand gripping a small bottle, mist, then soft foam.
    paintRect(NSRect(x:86,y:54,width:24,height:51),color(0xA8C3A0),radius:7,stroke:ink,width:2)
    paintRect(NSRect(x:86,y:49,width:21,height:9),ink,radius:3)
    paintRect(NSRect(x:79,y:47,width:13,height:6),ink,radius:2)
    oval(NSRect(x:96,y:75,width:24,height:18),color(0xEDC5A6),stroke:ink)
    line([NSPoint(x:119,y:83),NSPoint(x:144,y:109)],color(0xEDC5A6),15)
    for i in 0..<5 {line([NSPoint(x:77,y:53),NSPoint(x:39,y:42+CGFloat(i)*9)],color(0xBFD9DA),1.5)}
    }
    for i in 0..<9 {oval(NSRect(x:25+CGFloat(i%4)*12,y:65+CGFloat(i/4)*10,width:17,height:16),color(0xE8F3E8),stroke:color(0xBED5BE),width:1)}
}
func drawFriend(in box:NSRect,cat:Bool,phase:Double,facing:Double=1){
    NSGraphicsContext.saveGraphicsState()
    let t=AffineTransform(translationByX:box.minX,byY:box.minY);(t as NSAffineTransform).concat()
    let scale=AffineTransform(scaleByX:box.width/140,byY:box.height/140);(scale as NSAffineTransform).concat()
    if !cat && facing>0 {let flip=AffineTransform(translationByX:140,byY:0);(flip as NSAffineTransform).concat();let mirror=AffineTransform(scaleByX:-1,byY:1);(mirror as NSAffineTransform).concat()}
    if cat {
        paintRect(NSRect(x:78,y:28,width:66,height:88),color(0xE0AD78),radius:25,stroke:ink,width:3)
        oval(NSRect(x:18,y:37,width:95,height:82),color(0xEBC18D),stroke:ink,width:3)
        for n in 0..<4 {oval(NSRect(x:18+CGFloat(n)*21,y:36,width:28,height:36),color(0xF0CB9F),stroke:ink,width:2)}
        oval(NSRect(x:43,y:78,width:46,height:28),color(0xD99396))
        for n in 0..<3 {oval(NSRect(x:31+CGFloat(n)*22,y:57,width:14,height:17),color(0xD99396))}
    } else {
        let wig=sin(phase*12)*3
        let tail=NSBezierPath();tail.move(to:NSPoint(x:99,y:100));tail.curve(to:NSPoint(x:134,y:70+wig),controlPoint1:NSPoint(x:132,y:126),controlPoint2:NSPoint(x:137,y:103));ink.setStroke();tail.lineWidth=7;tail.stroke();color(0xDCA3A0).setStroke();tail.lineWidth=4;tail.stroke()
        oval(NSRect(x:18,y:112,width:94,height:12),color(0x765845,0.16))
        for x in [36.0,87.0] {oval(NSRect(x:x+wig,y:108,width:19,height:11),color(0xDCA3A0),stroke:ink,width:3)}
        oval(NSRect(x:23,y:38,width:27,height:30),color(0xA9978C),stroke:ink,width:3.5)
        oval(NSRect(x:29,y:44,width:15,height:18),color(0xDCA3A0))
        oval(NSRect(x:23,y:51,width:91,height:65),color(0xA9978C),stroke:ink,width:4)
        oval(NSRect(x:25,y:75,width:69,height:38),color(0xC6B7A6))
        // The near ear grows out of the head: leave the base contour open.
        let ear=NSBezierPath();ear.move(to:NSPoint(x:54,y:69))
        ear.curve(to:NSPoint(x:50,y:48),controlPoint1:NSPoint(x:48,y:65),controlPoint2:NSPoint(x:46,y:55))
        ear.curve(to:NSPoint(x:81,y:43),controlPoint1:NSPoint(x:54,y:33),controlPoint2:NSPoint(x:74,y:32))
        ear.curve(to:NSPoint(x:75,y:72),controlPoint1:NSPoint(x:91,y:56),controlPoint2:NSPoint(x:86,y:68))
        color(0xA9978C).setFill();ear.fill();ink.setStroke();ear.lineWidth=3.5;ear.lineCapStyle = .round;ear.stroke()
        oval(NSRect(x:56,y:43,width:23,height:23),color(0xE6B4AE))
        oval(NSRect(x:87,y:62,width:13,height:7),color(0xD3C3B4))
        oval(NSRect(x:100,y:72,width:5,height:5),color(0xD3C3B4))
        oval(NSRect(x:9,y:67,width:33,height:37),.white,stroke:ink,width:3.5)
        oval(NSRect(x:37,y:64,width:43,height:42),.white,stroke:ink,width:3.5)
        oval(NSRect(x:16,y:80,width:8,height:12),ink)
        oval(NSRect(x:47,y:79,width:9,height:13),ink)
        oval(NSRect(x:6,y:98,width:14,height:10),color(0xD68F96),stroke:ink,width:2.5)
        line([NSPoint(x:24,y:108),NSPoint(x:30,y:111),NSPoint(x:37,y:108)],ink,2)
        line([NSPoint(x:16,y:103),NSPoint(x:1,y:97)],ink,1.5)
        line([NSPoint(x:17,y:108),NSPoint(x:2,y:113)],ink,1.5)
    }
    NSGraphicsContext.restoreGraphicsState()
}
