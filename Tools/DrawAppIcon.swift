import AppKit
// Regenerate the app icon:  swiftc -O Tools/DrawAppIcon.swift -o /tmp/drawicon && /tmp/drawicon FocusTogether/Assets.xcassets/AppIcon.appiconset/AppIcon.png 0B0B0C FFFFFF FF6B2E

// Draws the Lockin padlock on a 1024×1024 canvas. Usage: draw <out.png> <bg> <lock> <keyhole> [transparentBG]
let args = CommandLine.arguments
func color(_ hex: String) -> CGColor {
    var v: UInt64 = 0; Scanner(string: hex).scanHexInt64(&v)
    return CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downwards, like a design tool.
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

if args.count < 6 {
    ctx.setFillColor(color(args[2])); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

// Leave breathing room around the lock (scaled about the centre).
ctx.translateBy(x: 512, y: 520); ctx.scaleBy(x: 0.84, y: 0.84); ctx.translateBy(x: -512, y: -520)

// Shackle
let cx: CGFloat = 512, r: CGFloat = 158, top: CGFloat = 395
ctx.setStrokeColor(color(args[3])); ctx.setLineWidth(78); ctx.setLineCap(.round)
let shackle = CGMutablePath()
shackle.move(to: CGPoint(x: cx - r, y: 500))
shackle.addLine(to: CGPoint(x: cx - r, y: top))
shackle.addArc(center: CGPoint(x: cx, y: top), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
shackle.addLine(to: CGPoint(x: cx + r, y: 500))
ctx.addPath(shackle); ctx.strokePath()

// Body
ctx.setFillColor(color(args[3]))
ctx.addPath(CGPath(roundedRect: CGRect(x: 262, y: 478, width: 500, height: 372), cornerWidth: 92, cornerHeight: 92, transform: nil))
ctx.fillPath()

// Keyhole
ctx.setFillColor(color(args[4]))
ctx.fillEllipse(in: CGRect(x: cx - 50, y: 586, width: 100, height: 100))
ctx.addPath(CGPath(roundedRect: CGRect(x: cx - 22, y: 636, width: 44, height: 118), cornerWidth: 22, cornerHeight: 22, transform: nil))
ctx.fillPath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
