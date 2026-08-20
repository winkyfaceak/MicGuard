// Renders the 1024x1024 master PNG the icon pipeline consumes.
//
// Pure CoreGraphics on purpose: no AppKit, no NSApplication, no SF Symbol
// lookup, so it runs headless under Command Line Tools with no Xcode.
//
// This is a placeholder you are meant to outgrow. Drop your own 1024x1024
// PNG at Resources/AppIcon.png and Scripts/icon.sh will use it instead.
//
//   swift Scripts/make-icon.swift Resources/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.png"
let canvas: CGFloat = 1024
let space = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: Int(canvas), height: Int(canvas),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("could not create bitmap context") }

// MARK: - Rounded-rect plate
//
// macOS icons sit inset inside the 1024 canvas rather than filling it, so
// they line up with every other icon in the Dock and Finder.

let inset: CGFloat = 92
let plate = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let plicePath = CGPath(roundedRect: plate, cornerWidth: 190, cornerHeight: 190, transform: nil)

ctx.saveGState()
ctx.addPath(plicePath)
ctx.clip()

let gradient = CGGradient(
    colorsSpace: space,
    colors: [
        CGColor(red: 0.30, green: 0.34, blue: 0.86, alpha: 1),
        CGColor(red: 0.12, green: 0.62, blue: 0.90, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: canvas),
    end: CGPoint(x: canvas, y: 0),
    options: []
)
ctx.restoreGState()

// MARK: - Microphone glyph
//
// Drawn by hand rather than pulled from SF Symbols, which would drag in
// AppKit and a running app instance.

ctx.saveGState()
ctx.translateBy(x: 0, y: -28)  // centre the glyph's visual mass on the plate
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(48)
ctx.setLineCap(.round)

// Capsule body.
let body = CGRect(x: 402, y: 430, width: 220, height: 380)
ctx.addPath(CGPath(roundedRect: body, cornerWidth: 110, cornerHeight: 110, transform: nil))
ctx.fillPath()

// Cradle: the lower half of a circle, open at the top.
ctx.addArc(
    center: CGPoint(x: 512, y: 560),
    radius: 200,
    startAngle: .pi,
    endAngle: 2 * .pi,
    clockwise: false
)
ctx.strokePath()

// Stem and base.
ctx.move(to: CGPoint(x: 512, y: 360))
ctx.addLine(to: CGPoint(x: 512, y: 272))
ctx.strokePath()

ctx.move(to: CGPoint(x: 410, y: 272))
ctx.addLine(to: CGPoint(x: 614, y: 272))
ctx.strokePath()

ctx.restoreGState()

// MARK: - Write PNG

guard let image = ctx.makeImage() else { fatalError("could not render image") }
let url = URL(fileURLWithPath: output)
guard let dest = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("could not create \(output)") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(output)") }

print("Wrote \(output) (\(Int(canvas))x\(Int(canvas)))")
