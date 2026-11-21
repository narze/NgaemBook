// Draws the NgaemBook logo as a 1024 x 1024 PNG.
// Usage: swift scripts/icon.swift <output.png>
//
// A night-sky app icon: the side view of a laptop that is only a little open
// (ajar) with a soft glow in the gap, and a crescent moon for "display asleep".
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Background: rounded square on the macOS icon grid (824 pt body, 100 pt margin), with a soft shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(shape)
ctx.setFillColor(color(0x10132E))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
let sky = CGGradient(colorsSpace: space, colors: [color(0x2B2F72), color(0x0A0C1E)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// Stars.
for (x, y, r) in [(250.0, 760.0, 7.0), (380, 680, 5), (540, 800, 6), (470, 590, 4), (830, 820, 5), (290, 580, 4)] {
    ctx.setFillColor(color(0xFFFFFF, 0.75))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

// Crescent moon: a circle with an offset circle cut out, glowing.
let moonCenter = CGPoint(x: 690, y: 665)
let moonRadius: CGFloat = 100
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 45, color: color(0xFFD66B, 0.6))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(color(0xFFD66B))
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: 2 * moonRadius, height: 2 * moonRadius))
ctx.setBlendMode(.destinationOut)
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonRadius + 50, y: moonCenter.y - moonRadius + 38, width: 2 * moonRadius, height: 2 * moonRadius))
ctx.endTransparencyLayer()
ctx.restoreGState()

// Laptop side view: hinge on the left, base to the right, lid open 20 degrees.
let hinge = CGPoint(x: 235, y: 300)
let length: CGFloat = 560
let thickness: CGFloat = 48
let angle: CGFloat = 20 * .pi / 180

// Soft glow in the gap between lid and base: a sector that fades out at both ends.
ctx.saveGState()
let sector = CGMutablePath()
sector.move(to: hinge)
sector.addArc(center: hinge, radius: length - 20, startAngle: 0, endAngle: angle, clockwise: false)
sector.closeSubpath()
ctx.addPath(sector)
ctx.clip()
let glow = CGGradient(
    colorsSpace: space,
    colors: [color(0x6FB6FF, 0.0), color(0x6FB6FF, 0.45), color(0x6FB6FF, 0.0)] as CFArray,
    locations: [0.15, 0.7, 1]
)!
ctx.drawRadialGradient(glow, startCenter: hinge, startRadius: 0, endCenter: hinge, endRadius: length - 20, options: [])
ctx.restoreGState()

// Base and lid.
func bar(to end: CGPoint, _ fill: CGColor) {
    ctx.setLineCap(.round)
    ctx.setLineWidth(thickness)
    ctx.setStrokeColor(fill)
    ctx.move(to: hinge)
    ctx.addLine(to: end)
    ctx.strokePath()
}
bar(to: CGPoint(x: hinge.x + length, y: hinge.y), color(0xAEB4C2))
bar(to: CGPoint(x: hinge.x + length * cos(angle), y: hinge.y + length * sin(angle)), color(0xF4F6FA))
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
